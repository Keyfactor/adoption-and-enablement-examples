package main

import (
	"bufio"
	"crypto"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/go-acme/lego/v4/acme"
	"github.com/go-acme/lego/v4/certificate"
	"github.com/go-acme/lego/v4/lego"
	"github.com/go-acme/lego/v4/registration"
	"golang.org/x/crypto/argon2"
)

const configFileName = "config.json"
const passphraseEnvVarName = "ACMECLIENT_PASSPHRASE"

var keyfactorACMEURLRegex = regexp.MustCompile(`^https:\/\/([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:[0-9]{1,5})?(\/[^\s]*)?$`)

type Config struct {
	AccountEmail  string `json:"accountEmail"`
	AccountURI    string `json:"accountUri"`
	OrdersURL     string `json:"ordersUrl"`
	AccountStatus string `json:"accountStatus"`

	AccountPrivateKeyEncrypted string `json:"accountPrivateKeyEncrypted"`
	AccountPrivateKeySalt      string `json:"accountPrivateKeySalt"`
	AccountPrivateKeyNonce     string `json:"accountPrivateKeyNonce"`

	EABKeyID            string `json:"eabKeyId"`
	EABHMACKeyEncrypted string `json:"eabHmacKeyEncrypted"`
	EABHMACKeySalt      string `json:"eabHmacKeySalt"`
	EABHMACKeyNonce     string `json:"eabHmacKeyNonce"`
	KeyfactorACMEURL    string `json:"keyfactorAcmeUrl"`
	ValidationEnabled   bool   `json:"validationEnabled"`
}

type PlainConfig struct {
	AccountEmail      string
	EABKeyID          string
	EABHMACKey        string
	KeyfactorACMEURL  string
	ValidationEnabled bool
}

type AcmeUser struct {
	Email        string
	Registration *registration.Resource
	PrivateKey   crypto.PrivateKey
}

func (u *AcmeUser) GetEmail() string {
	return u.Email
}

func (u *AcmeUser) GetRegistration() *registration.Resource {
	return u.Registration
}

func (u *AcmeUser) GetPrivateKey() crypto.PrivateKey {
	return u.PrivateKey
}

func main() {
	sanFlag := flag.String("san", "", "Comma-separated list of certificate SANs/domains, for example: example.com,www.example.com")
	outputDirFlag := flag.String("out", "output", "Directory where certificate files will be written")
	passphraseFlag := flag.String("passphrase", "", "Passphrase used to decrypt the ACME account private key. Prefer ACMECLIENT_PASSPHRASE for non-interactive use.")
	flag.Parse()

	passphrase := resolvePassphrase(*passphraseFlag)

	if _, err := os.Stat(configFileName); err == nil {
		client, config, err := loadACMEClientFromConfig(passphrase)
		if err != nil {
			fmt.Printf("Error loading ACME client from config: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Loaded ACME client for account: %s\n", config.AccountURI)
		fmt.Printf("ACME account status: %s\n", config.AccountStatus)

		if strings.TrimSpace(*sanFlag) == "" {
			fmt.Println("No SANs provided. Config loaded successfully.")
			fmt.Println("To request a certificate, run with -san example.com or -san example.com,www.example.com")
			return
		}

		sans, err := parseSANs(*sanFlag)
		if err != nil {
			fmt.Printf("Invalid SAN input: %v\n", err)
			os.Exit(1)
		}

		certResource, err := requestCertificate(client, config, sans)
		if err != nil {
			fmt.Printf("Error requesting certificate: %v\n", err)
			os.Exit(1)
		}

		if err := saveCertificateFiles(certResource, sans, *outputDirFlag); err != nil {
			fmt.Printf("Error saving certificate files: %v\n", err)
			os.Exit(1)
		}

		fmt.Printf("Certificate requested successfully for: %s\n", strings.Join(sans, ", "))
		fmt.Printf("Certificate files written to: %s\n", *outputDirFlag)
		return
	} else if !os.IsNotExist(err) {
		fmt.Printf("Error checking config file: %v\n", err)
		os.Exit(1)
	}

	if strings.TrimSpace(*sanFlag) != "" {
		fmt.Printf("Config file %q does not exist. Run without -san first to register the ACME account.\n", configFileName)
		os.Exit(1)
	}

	fmt.Printf("Config file %q not found. Creating one now.\n\n", configFileName)

	plainConfig, err := promptForConfig()
	if err != nil {
		fmt.Printf("Error reading input: %v\n", err)
		os.Exit(1)
	}

	if err := registerAndSaveConfig(plainConfig); err != nil {
		fmt.Printf("Error registering ACME account: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nConfig file %q created successfully.\n", configFileName)
}

func resolvePassphrase(passphraseFlag string) string {
	passphraseFlag = strings.TrimSpace(passphraseFlag)

	if passphraseFlag != "" {
		fmt.Println("Using passphrase from command-line flag: ********")
		return passphraseFlag
	}

	envPassphrase := strings.TrimSpace(os.Getenv(passphraseEnvVarName))
	if envPassphrase != "" {
		fmt.Printf("Using passphrase from environment variable %s: ********\n", passphraseEnvVarName)
		return envPassphrase
	}

	return ""
}

func promptForConfig() (PlainConfig, error) {
	reader := bufio.NewReader(os.Stdin)

	accountEmail, err := promptRequired(reader, "Enter ACME account email: ")
	if err != nil {
		return PlainConfig{}, err
	}

	eabKeyID, err := promptRequired(reader, "Enter EAB Key ID: ")
	if err != nil {
		return PlainConfig{}, err
	}

	eabHMACKey, err := promptRequired(reader, "Enter EAB HMAC Key: ")
	if err != nil {
		return PlainConfig{}, err
	}

	acmeURL, err := promptKeyfactorACMEURL(reader, "Enter Keyfactor ACME URL: ")
	if err != nil {
		return PlainConfig{}, err
	}

	validationEnabled, err := promptBool(reader, "Enable validation? true/false/t/f: ")
	if err != nil {
		return PlainConfig{}, err
	}

	return PlainConfig{
		AccountEmail:      accountEmail,
		EABKeyID:          eabKeyID,
		EABHMACKey:        eabHMACKey,
		KeyfactorACMEURL:  acmeURL,
		ValidationEnabled: validationEnabled,
	}, nil
}

func promptRequired(reader *bufio.Reader, message string) (string, error) {
	for {
		fmt.Print(message)

		input, err := reader.ReadString('\n')
		if err != nil {
			return "", err
		}

		input = strings.TrimSpace(input)
		if input != "" {
			return input, nil
		}

		fmt.Println("Value cannot be empty.")
	}
}

func promptKeyfactorACMEURL(reader *bufio.Reader, message string) (string, error) {
	for {
		input, err := promptRequired(reader, message)
		if err != nil {
			return "", err
		}

		input = strings.ToLower(input)

		if keyfactorACMEURLRegex.MatchString(input) {
			return input, nil
		}

		fmt.Println("Please enter a valid HTTPS URL, for example: https://domain.com/acme")
	}
}

func promptBool(reader *bufio.Reader, message string) (bool, error) {
	for {
		fmt.Print(message)

		input, err := reader.ReadString('\n')
		if err != nil {
			return false, err
		}

		input = strings.TrimSpace(strings.ToLower(input))

		switch input {
		case "true", "t":
			return true, nil
		case "false", "f":
			return false, nil
		default:
			fmt.Println("Please enter true, false, t, or f.")
		}
	}
}

func registerAndSaveConfig(plainConfig PlainConfig) error {
	reader := bufio.NewReader(os.Stdin)

	passphrase, err := promptRequired(reader, "Enter passphrase to encrypt secrets: ")
	if err != nil {
		return err
	}

	eabHMACEncoded, err := normalizeEABHMACKey(plainConfig.EABHMACKey)
	if err != nil {
		return err
	}

	plainConfig.EABHMACKey = eabHMACEncoded

	user, registrationResource, err := registerACMEAccount(plainConfig)
	if err != nil {
		return err
	}

	privateKeyPEM, err := encodeECPrivateKeyToPEM(user.PrivateKey)
	if err != nil {
		return err
	}

	accountPrivateKeyEncrypted, accountPrivateKeySalt, accountPrivateKeyNonce, err := encryptString(privateKeyPEM, passphrase)
	if err != nil {
		return err
	}

	eabEncryptedValue, eabSalt, eabNonce, err := encryptString(plainConfig.EABHMACKey, passphrase)
	if err != nil {
		return err
	}

	config := Config{
		AccountEmail:  plainConfig.AccountEmail,
		AccountURI:    registrationResource.URI,
		AccountStatus: registrationResource.Body.Status,

		AccountPrivateKeyEncrypted: accountPrivateKeyEncrypted,
		AccountPrivateKeySalt:      accountPrivateKeySalt,
		AccountPrivateKeyNonce:     accountPrivateKeyNonce,

		EABKeyID:            plainConfig.EABKeyID,
		EABHMACKeyEncrypted: eabEncryptedValue,
		EABHMACKeySalt:      eabSalt,
		EABHMACKeyNonce:     eabNonce,

		KeyfactorACMEURL:  plainConfig.KeyfactorACMEURL,
		ValidationEnabled: plainConfig.ValidationEnabled,
	}

	if registrationResource.Body.Orders != "" {
		config.OrdersURL = registrationResource.Body.Orders
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	if err := os.WriteFile(configFileName, data, 0600); err != nil {
		return err
	}

	fmt.Printf("ACME account registered successfully: %s\n", registrationResource.URI)

	return nil
}

func registerACMEAccount(config PlainConfig) (*AcmeUser, *registration.Resource, error) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, nil, err
	}

	user := &AcmeUser{
		Email:      config.AccountEmail,
		PrivateKey: privateKey,
	}

	legoConfig := lego.NewConfig(user)
	legoConfig.CADirURL = config.KeyfactorACMEURL

	client, err := lego.NewClient(legoConfig)
	if err != nil {
		return nil, nil, err
	}

	eabHMACEncoded, err := normalizeEABHMACKey(config.EABHMACKey)
	if err != nil {
		return nil, nil, err
	}

	registrationResource, err := client.Registration.RegisterWithExternalAccountBinding(registration.RegisterEABOptions{
		TermsOfServiceAgreed: true,
		Kid:                  config.EABKeyID,
		HmacEncoded:          eabHMACEncoded,
	})
	if err != nil {
		return nil, nil, err
	}

	user.Registration = registrationResource

	return user, registrationResource, nil
}

func normalizeEABHMACKey(value string) (string, error) {
	value = strings.TrimSpace(value)

	if value == "" {
		return "", fmt.Errorf("EAB HMAC key cannot be empty")
	}

	if decoded, err := base64.RawURLEncoding.DecodeString(value); err == nil {
		return base64.RawURLEncoding.EncodeToString(decoded), nil
	}

	if decoded, err := base64.URLEncoding.DecodeString(value); err == nil {
		return base64.RawURLEncoding.EncodeToString(decoded), nil
	}

	if decoded, err := base64.StdEncoding.DecodeString(value); err == nil {
		return base64.RawURLEncoding.EncodeToString(decoded), nil
	}

	if decoded, err := base64.RawStdEncoding.DecodeString(value); err == nil {
		return base64.RawURLEncoding.EncodeToString(decoded), nil
	}

	if decoded, err := hex.DecodeString(value); err == nil {
		return base64.RawURLEncoding.EncodeToString(decoded), nil
	}

	return "", fmt.Errorf("EAB HMAC key must be valid base64url, base64, or hex")
}

func loadACMEClientFromConfig(passphrase string) (*lego.Client, Config, error) {
	data, err := os.ReadFile(configFileName)
	if err != nil {
		return nil, Config{}, err
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, Config{}, err
	}

	if strings.TrimSpace(passphrase) == "" {
		reader := bufio.NewReader(os.Stdin)

		var err error
		passphrase, err = promptRequired(reader, "Enter passphrase to decrypt ACME account private key: ")
		if err != nil {
			return nil, Config{}, err
		}
	}

	privateKeyPEM, err := decryptString(
		config.AccountPrivateKeyEncrypted,
		config.AccountPrivateKeySalt,
		config.AccountPrivateKeyNonce,
		passphrase,
	)
	if err != nil {
		return nil, Config{}, err
	}

	privateKey, err := parseECPrivateKeyFromPEM(privateKeyPEM)
	if err != nil {
		return nil, Config{}, err
	}

	user := &AcmeUser{
		Email: config.AccountEmail,
		Registration: &registration.Resource{
			URI: config.AccountURI,
			Body: acme.Account{
				Status: config.AccountStatus,
				Orders: config.OrdersURL,
			},
		},
		PrivateKey: privateKey,
	}

	legoConfig := lego.NewConfig(user)
	legoConfig.CADirURL = config.KeyfactorACMEURL

	client, err := lego.NewClient(legoConfig)
	if err != nil {
		return nil, Config{}, err
	}

	return client, config, nil
}

func encodeECPrivateKeyToPEM(privateKey crypto.PrivateKey) (string, error) {
	ecdsaPrivateKey, ok := privateKey.(*ecdsa.PrivateKey)
	if !ok {
		return "", fmt.Errorf("private key is not an ECDSA private key")
	}

	keyBytes, err := x509.MarshalECPrivateKey(ecdsaPrivateKey)
	if err != nil {
		return "", err
	}

	pemBytes := pem.EncodeToMemory(&pem.Block{
		Type:  "EC PRIVATE KEY",
		Bytes: keyBytes,
	})

	return string(pemBytes), nil
}

func parseECPrivateKeyFromPEM(privateKeyPEM string) (*ecdsa.PrivateKey, error) {
	block, _ := pem.Decode([]byte(privateKeyPEM))
	if block == nil {
		return nil, fmt.Errorf("failed to decode private key PEM")
	}

	privateKey, err := x509.ParseECPrivateKey(block.Bytes)
	if err != nil {
		return nil, err
	}

	return privateKey, nil
}

func encryptString(plainText string, passphrase string) (encryptedValue string, saltValue string, nonceValue string, err error) {
	salt := make([]byte, 16)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return "", "", "", err
	}

	key := deriveKey(passphrase, salt)

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", "", "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", "", "", err
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", "", "", err
	}

	cipherText := aesGCM.Seal(nil, nonce, []byte(plainText), nil)

	return base64.StdEncoding.EncodeToString(cipherText),
		base64.StdEncoding.EncodeToString(salt),
		base64.StdEncoding.EncodeToString(nonce),
		nil
}

func decryptString(encryptedValue string, saltValue string, nonceValue string, passphrase string) (string, error) {
	cipherText, err := base64.StdEncoding.DecodeString(encryptedValue)
	if err != nil {
		return "", err
	}

	salt, err := base64.StdEncoding.DecodeString(saltValue)
	if err != nil {
		return "", err
	}

	nonce, err := base64.StdEncoding.DecodeString(nonceValue)
	if err != nil {
		return "", err
	}

	key := deriveKey(passphrase, salt)

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	plainText, err := aesGCM.Open(nil, nonce, cipherText, nil)
	if err != nil {
		return "", err
	}

	return string(plainText), nil
}

func parseSANs(input string) ([]string, error) {
	parts := strings.Split(input, ",")
	sans := make([]string, 0, len(parts))
	seen := make(map[string]bool)

	for _, part := range parts {
		san := strings.TrimSpace(strings.ToLower(part))
		if san == "" {
			continue
		}

		if strings.HasPrefix(san, "http://") || strings.HasPrefix(san, "https://") {
			return nil, fmt.Errorf("SAN must be a domain name, not a URL: %s", san)
		}

		if !isValidDomainOrWildcard(san) {
			return nil, fmt.Errorf("invalid SAN/domain: %s", san)
		}

		if !seen[san] {
			sans = append(sans, san)
			seen[san] = true
		}
	}

	if len(sans) == 0 {
		return nil, fmt.Errorf("at least one SAN is required")
	}

	return sans, nil
}

func isValidDomainOrWildcard(value string) bool {
	domainRegex := regexp.MustCompile(`^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$`)
	wildcardRegex := regexp.MustCompile(`^\*\.([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,}$`)

	return domainRegex.MatchString(value) || wildcardRegex.MatchString(value)
}

func requestCertificate(client *lego.Client, config Config, sans []string) (*certificate.Resource, error) {
	if config.ValidationEnabled {
		fmt.Println("Validation is enabled. Make sure a challenge provider is configured before requesting certificates.")
	} else {
		fmt.Println("Validation is disabled in config. Requesting certificate without configuring a local challenge provider.")
	}

	request := certificate.ObtainRequest{
		Domains: sans,
		Bundle:  true,
	}

	return client.Certificate.Obtain(request)
}

func saveCertificateFiles(certResource *certificate.Resource, sans []string, outputDir string) error {
	if certResource == nil {
		return fmt.Errorf("certificate resource is nil")
	}

	if len(sans) == 0 {
		return fmt.Errorf("at least one SAN is required")
	}

	baseName := sanitizeFileName(sans[0])
	timestamp := time.Now().Format("20060102_150405")
	certificateOutputDir := filepath.Join(outputDir, baseName+"_"+timestamp)

	if err := os.MkdirAll(certificateOutputDir, 0700); err != nil {
		return err
	}

	certPath := filepath.Join(certificateOutputDir, baseName+".crt")
	issuerPath := filepath.Join(certificateOutputDir, baseName+".issuer.crt")
	keyPath := filepath.Join(certificateOutputDir, baseName+".key")
	jsonPath := filepath.Join(certificateOutputDir, baseName+".certificate.json")

	if err := os.WriteFile(certPath, certResource.Certificate, 0600); err != nil {
		return err
	}

	if len(certResource.IssuerCertificate) > 0 {
		if err := os.WriteFile(issuerPath, certResource.IssuerCertificate, 0600); err != nil {
			return err
		}
	}

	if err := os.WriteFile(keyPath, certResource.PrivateKey, 0600); err != nil {
		return err
	}

	metadata := map[string]any{
		"domain":      certResource.Domain,
		"certUrl":     certResource.CertURL,
		"certStable":  certResource.CertStableURL,
		"sans":        sans,
		"outputDir":   certificateOutputDir,
		"certPath":    certPath,
		"issuerPath":  issuerPath,
		"keyPath":     keyPath,
		"requestedAt": time.Now().Format(time.RFC3339),
	}

	metadataBytes, err := json.MarshalIndent(metadata, "", "  ")
	if err != nil {
		return err
	}

	if err := os.WriteFile(jsonPath, metadataBytes, 0600); err != nil {
		return err
	}

	fmt.Printf("Output directory: %s\n", certificateOutputDir)
	fmt.Printf("Certificate: %s\n", certPath)
	if len(certResource.IssuerCertificate) > 0 {
		fmt.Printf("Issuer certificate: %s\n", issuerPath)
	}
	fmt.Printf("Private key: %s\n", keyPath)
	fmt.Printf("Metadata: %s\n", jsonPath)

	return nil
}

func sanitizeFileName(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	value = strings.ReplaceAll(value, "*", "wildcard")
	value = strings.ReplaceAll(value, ".", "_")
	value = strings.ReplaceAll(value, ":", "_")
	value = strings.ReplaceAll(value, "/", "_")
	value = strings.ReplaceAll(value, "\\", "_")

	return value
}

func deriveKey(passphrase string, salt []byte) []byte {
	return argon2.IDKey(
		[]byte(passphrase),
		salt,
		3,
		64*1024,
		4,
		32,
	)
}
