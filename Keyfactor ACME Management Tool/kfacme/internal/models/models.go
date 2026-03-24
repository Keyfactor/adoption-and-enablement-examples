package models

type StatusResponse struct {
	Status string `json:"status"`
}

type ErrorResponse struct {
	Message string `json:"message"`
}

type OIDCMetadata struct {
	TokenEndpoint string `json:"token_endpoint"`
	JWKSURI       string `json:"jwks_uri"`
	Issuer        string `json:"issuer"`
}
