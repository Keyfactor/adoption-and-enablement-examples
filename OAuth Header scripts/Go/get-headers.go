package main

import (
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strings"
)

// Define script level variables for the script using a map
var Variables = map[string]interface{}{
	// Authentication method (basic or oauth)
	"Auth_Method": "oauth",
	// Keyfactor's user credentials if Auth variable is set to Basic
	"keyfactorUser":     "username",
	"keyfactorPassword": "password",

	// OAuth-specific parameters if Auth variable is set to oauth
	"client_id":     "<ClientID>",
	"client_secret": "<ClientSecret>",
	"token_url":     "<TokenURL>",
	"scope":         "<SCOPE>",
	"audience":      "<SCOPE>",
	"GlobalHeaders": map[string]string{
		"Content-Type":                  "application/json",
		"x-keyfactor-requested-with":    "APIClient",
	},
}

func GetHeaders(apiVersion string) (map[string]string, error) {
	/*
	   Retrieve HTTP headers for API communication based on the configured
	   authentication method.

	   The function dynamically generates the required headers depending
	   on whether the chosen authentication method is OAuth or Basic
	   Authentication. If OAuth is utilized, it manages token retrieval
	   with client credentials and constructs the appropriate header.
	   With Basic Authentication, it encodes the credentials and formats
	   them for use.

	   :param apiVersion: The version of the API to be included in the
	       "x-keyfactor-api-version" header. Defaults to "1".
	   :type apiVersion: string
	   :return: A map containing the HTTP headers tailored to the
	       specified API version and authentication method.
	   :rtype: map[string]string
	   :raises error: Raised if the OAuth token retrieval process fails.
	*/
	if Variables["Auth_Method"] == "oauth" {
		authHeaders := map[string]string{
			"Content-Type": "application/x-www-form-urlencoded",
		}

		authBody := url.Values{}
		authBody.Set("grant_type", "client_credentials")
		authBody.Set("client_id", Variables["client_id"].(string))
		authBody.Set("client_secret", Variables["client_secret"].(string))

		if scope, ok := Variables["scope"].(string); ok && scope != "" {
			authBody.Set("scope", scope)
		}
		if audience, ok := Variables["audience"].(string); ok && audience != "" {
			authBody.Set("audience", audience)
		}

		resp, err := http.PostForm(Variables["token_url"].(string), authBody)
		if err != nil {
			fmt.Printf("Failed to fetch OAuth token: %s\n", err.Error())
			return nil, err
		}
		defer resp.Body.Close()
		if resp.StatusCode != http.StatusOK {
			return nil, errors.New("failed to fetch OAuth token: invalid response")
		}

		var responseBody map[string]interface{}
		if err := json.NewDecoder(resp.Body).Decode(&responseBody); err != nil {
			return nil, err
		}

		token, ok := responseBody["access_token"].(string)
		if !ok {
			return nil, errors.New("failed to fetch OAuth token: no access_token in response")
		}

		fmt.Println("Access Token received successfully.")
		headers := make(map[string]string)
		for k, v := range Variables["GlobalHeaders"].(map[string]string) {
			headers[k] = v
		}
		headers["Authorization"] = "Bearer " + token
		headers["x-keyfactor-api-version"] = apiVersion

		return headers, nil
	} else if Variables["Auth_Method"] == "basic" {
		user := Variables["keyfactorUser"].(string)
		password := Variables["keyfactorPassword"].(string)
		userPass := fmt.Sprintf("%s:%s", user, password)
		authInfo := base64.StdEncoding.EncodeToString([]byte(userPass))

		headers := make(map[string]string)
		for k, v := range Variables["GlobalHeaders"].(map[string]string) {
			headers[k] = v
		}
		headers["Authorization"] = "Basic " + authInfo
		headers["x-keyfactor-api-version"] = apiVersion

		return headers, nil
	}

	return nil, errors.New("invalid Auth_Method specified")
}