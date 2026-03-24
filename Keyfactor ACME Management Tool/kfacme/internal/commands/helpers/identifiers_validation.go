package helpers

import (
	"encoding/json"
	"fmt"
	"io"
	"kfacme/internal/acme_client"
	"net"
	"regexp"
	"strings"
)

// acmeClient is expected to be provided by your codebase.
type AppSettingsResponse interface {
	Text() string
}

// _is_wildcard_enabled checks whether the "Allow Wildcard Enrollments" setting is true.
func IsWildcardEnabled(acme *acme_client.AcmeClient) (bool, error) {
	if acme == nil {
		return false, fmt.Errorf("acme client is nil")
	}

	resp, err := acme.AppSettingsGet("")
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return false, err
	}

	var settings []map[string]any
	if err := json.Unmarshal(body, &settings); err != nil {
		return false, err
	}

	for _, setting := range settings {
		if name, ok := setting["name"].(string); ok && name == "Allow Wildcard Enrollments" {
			val := ""
			if v, exists := setting["value"]; exists && v != nil {
				val = strings.ToLower(strings.TrimSpace(strings.Trim(fmt.Sprint(v), `"`)))
			}
			return val == "true", nil
		}
	}

	return false, nil
}

// _is_valid_fqdn validates a fully qualified domain name.
func IsValidFQDN(domain string) bool {
	domain = strings.TrimSpace(domain)

	if domain == "" || len(domain) > 253 {
		return false
	}

	// Must contain at least one dot
	parts := strings.Split(domain, ".")
	if len(parts) < 2 {
		return false
	}

	// Reject IP addresses
	if net.ParseIP(domain) != nil {
		return false
	}

	labelRe := regexp.MustCompile(`^[a-zA-Z0-9-]{1,63}$`)

	for _, part := range parts {
		if part == "" {
			return false
		}
		if !labelRe.MatchString(part) {
			return false
		}
		if strings.HasPrefix(part, "-") || strings.HasSuffix(part, "-") {
			return false
		}
	}

	return true
}

// _is_valid_subnet validates a subnet/CIDR using net.ParseCIDR.
// strict=False behavior is approximated by accepting any parseable CIDR/network input.
func IsValidSubnet(subnet string) bool {
	_, _, err := net.ParseCIDR(subnet)
	return err == nil
}

// _is_valid_regex validates whether a pattern compiles as a regular expression.
func IsValidRegex(pattern string) bool {
	_, err := regexp.Compile(pattern)
	return err == nil
}

// _is_valid_wildcard_domain validates wildcard domains like *.example.com.
func IsValidWildcardDomain(domain string) bool {
	wildcardPattern := regexp.MustCompile(`^\*\.[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$`)
	if !wildcardPattern.MatchString(domain) {
		return false
	}

	fqdnPart := domain[2:] // remove "*."
	parts := strings.Split(fqdnPart, ".")
	if len(parts) < 2 {
		return false
	}

	for _, part := range parts {
		if part == "" || len(part) > 63 {
			return false
		}
		if strings.HasPrefix(part, "-") || strings.HasSuffix(part, "-") {
			return false
		}
		if !regexp.MustCompile(`^[a-zA-Z0-9-]+$`).MatchString(part) {
			return false
		}
	}

	return true
}
