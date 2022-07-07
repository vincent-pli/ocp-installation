/*
Copyright © 2022 NAME HERE <EMAIL ADDRESS>

*/
package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
	"github.com/vincent-pli/ocp-installation/pkg/config"
)

var installArgs config.Args

// installCmd represents the install command
var installCmd = &cobra.Command{
	Use:   "install",
	Short: "A brief description of your command",
	Long: `A longer description that spans multiple lines and likely contains examples
and usage of using your command. For example:

Cobra is a CLI library for Go that empowers applications.
This application is a tool to generate the needed files
to quickly create a Cobra application.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("install called")
		fmt.Println(installArgs)
	},
}

func init() {
	installArgs = config.Args{}
	rootCmd.AddCommand(installCmd)

	// Here you will define your flags and configuration settings.

	// Cobra supports Persistent Flags which will work for this command
	// and all subcommands, e.g.:
	// installCmd.PersistentFlags().String("foo", "", "A help for foo")

	// Cobra supports local flags which will only run when this command
	// is called directly, e.g.:
	installCmd.Flags().StringVarP(&installArgs.Masters, "masters", "m", "", "set count or IPList to masters")
	installCmd.Flags().StringVarP(&installArgs.Nodes, "nodes", "n", "", "set count or IPList to nodes")
	installCmd.Flags().StringVarP(&installArgs.User, "user", "u", "root", "set baremetal server username")
	installCmd.Flags().StringVarP(&installArgs.Password, "passwd", "p", "", "set cloud provider or baremetal server password")
	installCmd.Flags().StringVarP(&installArgs.Bastion, "bastion", "b", "", "IP address of bastion")
	installCmd.Flags().StringVarP(&installArgs.OCPAdmin, "ocpadmin", "", "ocadmin", "Administrator of OCP")
	installCmd.Flags().StringVarP(&installArgs.OCPPass, "ocpadmpass", "", "letmein", "Password of administrator of OCP")
	installCmd.Flags().StringVarP(&installArgs.OCPPass, "ocpadmpass", "", "letmein", "Password of administrator of OCP")
}
