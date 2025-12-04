# Azure Virtual Desktop (AVD) Deployment Guide

## Overview

This repository contains a collection of scripts and step-by-step guides to deploy a complete Azure Virtual Desktop (AVD) environment. The process covers everything from initial network and storage setup to session host deployment, Intune configuration, and final testing.

## Prerequisites

Before you begin, ensure you have the following:

- An active Azure Subscription.
- A user account with 'Owner' or 'Contributor' and 'User Access Administrator' roles on the subscription.
- Azure CLI installed and configured.
- PowerShell with the Az module installed.
- You are logged into your Azure account via `az login`.

## Workflow Steps

Follow the steps below in order. Each step corresponds to a directory containing detailed instructions and any necessary scripts.

1.  **Networking Setup**
    *   Provisions the core networking infrastructure, including the VNet, subnets, and Network Security Groups.
    *   [View Details](./01-networking/01-Networking-Setup.md)

2.  **Storage Setup**
    *   Creates the Azure Files share that will be used for FSLogix user profiles.
    *   [View Details](./02-storage/02-Storage-Setup.md)

3.  **Entra ID Group Setup**
    *   Creates the necessary Microsoft Entra ID (formerly Azure AD) groups for managing user and administrator access to the AVD environment.
    *   [View Details](./03-entra-group/03-Entra-Group-Setup.md)

4.  **Host Pool & Workspace Setup**
    *   Creates the AVD Host Pool, Application Group, and Workspace.
    *   [View Details](./04-host-pool-workspace/04-Host-Pool-Workspace-Setup.md)

5.  **Golden Image Creation**
    *   Guides you through creating and configuring a "golden image" VM with all necessary applications and settings. This image will be used as a template for the session hosts.
    *   [View Details](./05-golden-image/05-Golden-Image-Creation.md)

6.  **Session Host Deployment**
    *   Deploys session host VMs into the host pool using the golden image created in the previous step.
    *   [View Details](./06-session-host-deployment/06-Session-Host-Deployment.md)

7.  **Intune Configuration**
    *   Enrolls the session hosts into Microsoft Intune and applies configuration policies for management and security.
    *   [View Details](./07-intune/07-Intune-Configuration.md)

8.  **RBAC Assignments**
    *   Assigns the appropriate Role-Based Access Control (RBAC) permissions to the Entra ID groups, granting users access to the AVD resources.
    *   [View Details](./08-rbac/08-RBAC-Assignments.md)

9.  **SSO Configuration**
    *   Configures Kerberos and enables Single Sign-On (SSO) for a seamless user login experience.
    *   [View Details](./09-sso/09-SSO-Configuration.md)

10. **Autoscaling Setup**
    *   Sets up autoscaling plans to automatically start and stop session host VMs based on a schedule, optimizing costs.
    *   [View Details](./10-autoscaling/10-Autoscaling-Setup.md)

11. **Testing & Validation**
    *   Provides a checklist for testing the end-to-end user experience, from logging in to application usage.
    *   [View Details](./11-testing/11-Testing-Validation.md)

12. **VM Cleanup & Migration**
    *   Includes steps for cleaning up temporary resources and preparing the environment for production.
    *   [View Details](./12-cleanup-migration/12-VM-Cleanup-Migration.md)

## Shared Utilities

The `common/` directory contains scripts that may be used for debugging or recovery purposes across multiple steps.

- `debug_apps.ps1`: Script to assist with debugging application installations.
- `recover_vm.sh`: Script to aid in recovering a VM.

## Usage

Start with Step 1 and proceed sequentially. Navigate into each directory and follow the instructions within the markdown file.
