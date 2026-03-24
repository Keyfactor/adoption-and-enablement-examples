package acme_client

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type Variables map[string]string

type AcmeClient struct {
	Vars        Variables
	Client      *http.Client
	Retries     int
	Backoff     time.Duration
	AccessToken string
}

type OIDCMetadata struct {
	TokenEndpoint string `json:"token_endpoint"`
	JWKSURI       string `json:"jwks_uri"`
	Issuer        string `json:"issuer"`
}

func NewAcmeClient(vars Variables, retries int, backoffSeconds int) *AcmeClient {
	if retries < 1 {
		retries = 1
	}
	if backoffSeconds < 0 {
		backoffSeconds = 0
	}

	return &AcmeClient{
		Vars:    vars,
		Client:  &http.Client{Timeout: 60 * time.Second},
		Retries: retries,
		Backoff: time.Duration(backoffSeconds) * time.Second,
	}
}

func (c *AcmeClient) InitializeAuth(ctx context.Context) error {
	if c == nil {
		return fmt.Errorf("acme client is nil")
	}
	if c.Client == nil {
		c.Client = &http.Client{Timeout: 60 * time.Second}
	}

	discoveryURL := c.Vars["oidc_discovery_url"]
	if discoveryURL == "" {
		return fmt.Errorf("oidc_discovery_url is required")
	}

	clientID := c.Vars["client_id"]
	if clientID == "" {
		return fmt.Errorf("client_id is required")
	}

	clientSecret := c.Vars["client_secret"]
	if clientSecret == "" {
		return fmt.Errorf("client_secret is required")
	}

	meta, err := c.fetchOIDCMetadata(ctx, discoveryURL)
	if err != nil {
		return err
	}

	token, err := c.fetchClientCredentialsToken(
		ctx,
		meta.TokenEndpoint,
		clientID,
		clientSecret,
		c.Vars["scope"],
		c.Vars["audience"],
	)
	if err != nil {
		return err
	}

	c.AccessToken = token
	return nil
}

func (c *AcmeClient) GetTokenWithCredentials(ctx context.Context, clientID, clientSecret string) (string, error) {
	meta, err := c.fetchOIDCMetadata(ctx, c.Vars["oidc_discovery_url"])
	if err != nil {
		return "", err
	}

	return c.fetchClientCredentialsToken(
		ctx,
		meta.TokenEndpoint,
		clientID,
		clientSecret,
		c.Vars["scope"],
		c.Vars["audience"],
	)
}

func (c *AcmeClient) fetchOIDCMetadata(ctx context.Context, discoveryURL string) (*OIDCMetadata, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, discoveryURL, nil)
	if err != nil {
		return nil, fmt.Errorf("build discovery request: %w", err)
	}

	resp, err := c.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch discovery document: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("discovery request failed: %s", resp.Status)
	}

	var meta OIDCMetadata
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		return nil, fmt.Errorf("decode discovery document: %w", err)
	}
	if meta.TokenEndpoint == "" {
		return nil, fmt.Errorf("discovery document missing token_endpoint")
	}

	return &meta, nil
}

func (c *AcmeClient) fetchClientCredentialsToken(
	ctx context.Context,
	tokenURL, clientID, clientSecret, scope, audience string,
) (string, error) {
	form := url.Values{}
	form.Set("grant_type", "client_credentials")
	form.Set("client_id", clientID)
	form.Set("client_secret", clientSecret)
	if scope != "" {
		form.Set("scope", scope)
	}
	if audience != "" {
		form.Set("audience", audience)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		return "", fmt.Errorf("build token request: %w", err)
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.Client.Do(req)
	if err != nil {
		return "", fmt.Errorf("request token: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("read token response body: %w", err)
	}

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("token request failed: %s: %s", resp.Status, string(body))
	}

	var tokenResp struct {
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(bytes.NewReader(body)).Decode(&tokenResp); err != nil {
		return "", fmt.Errorf("decode token response: %w", err)
	}
	if tokenResp.AccessToken == "" {
		return "", fmt.Errorf("missing access_token in token response")
	}

	return tokenResp.AccessToken, nil
}

func (c *AcmeClient) buildURL(endpoint string, apiType string) string {
	base := strings.TrimRight(c.Vars["acme_dns"], "/")
	if apiType == "keyfactor" {
		base = strings.TrimRight(c.Vars["KeyfactorURL"], "/")
	}
	return base + "/" + strings.TrimLeft(endpoint, "/")
}

func (c *AcmeClient) createAuthHeaders(apiType string) (map[string]string, error) {
	if c.AccessToken == "" {
		return nil, fmt.Errorf("access token is empty; call InitializeAuth first")
	}

	headers := map[string]string{
		"Authorization": "Bearer " + c.AccessToken,
	}

	if apiType == "" {
		headers["Content-Type"] = "application/json"
		return headers, nil
	}
	if apiType == "keyfactor" {
		headers["x-keyfactor-requested-with"] = "APIClient"
		headers["x-keyfactor-api-version"] = "1.0"
		return headers, nil
	}

	return nil, fmt.Errorf("unsupported API type: %s", apiType)
}

func (c *AcmeClient) requestWithRetry(method, urlStr string, headers map[string]string, body []byte) (*http.Response, error) {
	var lastErr error

	for attempt := 1; attempt <= c.Retries; attempt++ {
		var reqBody io.Reader
		if body != nil {
			reqBody = bytes.NewReader(body)
		}

		req, err := http.NewRequest(method, urlStr, reqBody)
		if err != nil {
			return nil, err
		}

		for k, v := range headers {
			req.Header.Set(k, v)
		}

		resp, err := c.Client.Do(req)
		if err == nil && resp.StatusCode >= 200 && resp.StatusCode < 300 {
			return resp, nil
		}

		if resp != nil {
			defer resp.Body.Close()
			b, _ := io.ReadAll(resp.Body)
			if err == nil {
				err = fmt.Errorf("request failed: %s: %s", resp.Status, string(b))
			}
		}

		lastErr = err
		if attempt < c.Retries {
			time.Sleep(c.Backoff)
		}
	}

	return nil, lastErr
}

func (c *AcmeClient) do(method, endpoint, apiType string, body any) (*http.Response, error) {
	headers, err := c.createAuthHeaders(apiType)
	if err != nil {
		return nil, err
	}

	var payload []byte
	if body != nil {
		payload, err = json.Marshal(body)
		if err != nil {
			return nil, err
		}
	}

	return c.requestWithRetry(method, c.buildURL(endpoint, apiType), headers, payload)
}

func (c *AcmeClient) Get(endpoint, apiType string) (*http.Response, error) {
	return c.do("GET", endpoint, apiType, nil)
}

func (c *AcmeClient) Post(endpoint string, body map[string]any, apiType string) (*http.Response, error) {
	return c.do("POST", endpoint, apiType, body)
}

func (c *AcmeClient) Put(endpoint string, body any, apiType string) (*http.Response, error) {
	return c.do("PUT", endpoint, apiType, body)
}

func (c *AcmeClient) Delete(endpoint, apiType string) (*http.Response, error) {
	return c.do("DELETE", endpoint, apiType, nil)
}

func (c *AcmeClient) StatusGet(apiType string) (bool, error) {
	resp, err := c.Get("status", apiType)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	return resp.StatusCode == http.StatusNoContent, nil
}

func (c *AcmeClient) ClaimPut(id string, body any, apiType string) (*http.Response, error) {
	return c.Put("Claims/"+id, body, apiType)
}

func (c *AcmeClient) ClaimPost(body map[string]any, apiType string) (*http.Response, error) {
	return c.Post("Claims", body, apiType)
}

func (c *AcmeClient) ClaimGet(id string, apiType string) (*http.Response, error) {
	if id == "" {
		return c.Get("Claims", apiType)
	}
	return c.Get("Claims/"+id, apiType)
}

func (c *AcmeClient) ClaimDelete(id string, apiType string) (*http.Response, error) {
	return c.Delete("Claims/"+id, apiType)
}

func (c *AcmeClient) KeyManagementGet(template string, extraHeaders map[string]string, apiType string) (*http.Response, error) {
	headers, err := c.createAuthHeaders(apiType)
	if err != nil {
		return nil, err
	}
	for k, v := range extraHeaders {
		headers[k] = v
	}

	endpoint := fmt.Sprintf("KeyManagement?Template=%s", url.QueryEscape(template))
	return c.requestWithRetry("GET", c.buildURL(endpoint, apiType), headers, nil)
}

func (c *AcmeClient) KeyManagementPost(body map[string]any, apiType string) (*http.Response, error) {
	return c.Post("KeyManagement", body, apiType)
}

func (c *AcmeClient) IdentifierAddPost(body map[string]any, apiType string) (*http.Response, error) {
	return c.Post("Identifiers", body, apiType)
}

func (c *AcmeClient) IdentifierGet(apiType string) (*http.Response, error) {
	return c.Get("Identifiers", apiType)
}

func (c *AcmeClient) IdentifierDelete(id string, apiType string) (*http.Response, error) {
	return c.Delete("Identifiers/"+id, apiType)
}

func (c *AcmeClient) AdminAccountsPut(id string, body any, apiType string) (*http.Response, error) {
	return c.Put("Admin/Accounts/"+id, body, apiType)
}

func (c *AcmeClient) AdminAccountsGet(apiType string) (*http.Response, error) {
	return c.Get("Admin/Accounts/List", apiType)
}

func (c *AcmeClient) AdminAccountsRevokePost(accountID string, deleteKey bool, apiType string) (*http.Response, error) {
	endpoint := fmt.Sprintf("Admin/Accounts/Revoke?accountId=%s", url.QueryEscape(accountID))
	if deleteKey {
		endpoint += "&deleteKey=true"
	}
	return c.Post(endpoint, nil, apiType)
}

func (c *AcmeClient) AppSettingsGet(apiType string) (*http.Response, error) {
	return c.Get("AppSettings", apiType)
}

func (c *AcmeClient) AppSettingsPut(id int, value any, apiType string) (*http.Response, error) {
	return c.Put(fmt.Sprintf("AppSettings/%d", id), value, apiType)
}

func (c *AcmeClient) TemplatePatternsGet(apiType string) (*http.Response, error) {
	endpoint := `EnrollmentPatterns?QueryString=AllowedEnrollmentType%20-eq%20%222%22&ReturnLimit=100`
	return c.Get(endpoint, apiType)
}
