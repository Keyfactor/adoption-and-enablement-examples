package sub

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
)

func ExtractSubFromToken(token string) (string, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return "", fmt.Errorf("invalid JWT format")
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return "", fmt.Errorf("decode JWT payload: %w", err)
	}

	var decodedToken map[string]any
	if err := json.Unmarshal(payload, &decodedToken); err != nil {
		return "", fmt.Errorf("unmarshal JWT payload: %w", err)
	}

	subVal, ok := decodedToken["sub"]
	if !ok || fmt.Sprint(subVal) == "" {
		return "", fmt.Errorf("decoded token does not contain 'sub'")
	}

	return fmt.Sprint(subVal), nil
}
