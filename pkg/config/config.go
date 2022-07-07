package config

type Args struct {
	Bastion            string
	Masters            string
	Nodes              string
	User               string
	Password           string
	OCPAdmin           string
	OCPPass            string
	NTPServers         []string
	NTPAllow           string
	Gateway            string
	ExternalNameServer string
	InterfaceName      string
	InterfaceScript    string
}
