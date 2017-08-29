# AzureRM.AutoScale.ps1

A PowerShell script to automatically start/shutdown Azure Virtual Machines and Azure Analysis Services instances and in the later change the SKU (scaling).

This script was created to be run on Azure Automation but it also runs locally.

Find a guide on how to configure an Azure Automation Account here:

* https://ruiromanoblog.wordpress.com/2017/05/06/automatically-pauseresume-and-scale-updown-your-azure-analysis-services-using-azurerm-analysisservices/

## Parameters

	* azureProfilePath - Optional - Path to an Azure Profile file to run the script locally
	* azureRunAsConnectionName - Name of the Azure Automation Account to runt he script in a Azure Runbook
	* config - List of the resources that the script will manage
		
