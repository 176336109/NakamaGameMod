package config

import (
	"os"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server    ServerConfig     `yaml:"server"`
	DB        DBConfig         `yaml:"db"`
	Redis     RedisConfig      `yaml:"redis"`
	Providers []ProviderConfig `yaml:"providers"`
	Business  BusinessConfig   `yaml:"business"`
}

type ServerConfig struct {
	Addr string `yaml:"addr"`
}

type DBConfig struct {
	DSN  string `yaml:"dsn"`
	Type string `yaml:"type"` // postgres, mysql
}

type RedisConfig struct {
	Addr string `yaml:"addr"`
}

type ProviderConfig struct {
	Name             string `yaml:"name"`
	AppID            string `yaml:"app_id"`
	MchID            string `yaml:"mchid"`
	SerialNo         string `yaml:"serial_no"`
	ApiV3Key         string `yaml:"api_v3_key"`
	PrivateKeyPath   string `yaml:"private_key_path"`
	PublicKeyPath    string `yaml:"public_key_path"`
	NotifyPath       string `yaml:"notify_path"`
	BaseURL          string `yaml:"base_url"`           // For custom provider
	AppKey           string `yaml:"app_key"`            // For custom provider
	AppSecret        string `yaml:"app_secret"`         // For custom provider
	NotifyExpectBody string `yaml:"notify_expect_body"` // For custom provider
}

type BusinessConfig struct {
	NakamaNotifyURL string `yaml:"nakama_notify_url"`
	NakamaServerKey string `yaml:"nakama_server_key"` // Optional: for auth
	NakamaApiURL    string `yaml:"nakama_api_url"`
	SignSecret      string `yaml:"sign_secret"`
}

// Global config variable
var C Config

func LoadConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return yaml.Unmarshal(data, &C)
}
