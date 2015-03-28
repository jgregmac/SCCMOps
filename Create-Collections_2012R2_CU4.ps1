﻿# -------------------------------------------------------------------
# Author: Ronni Pedersen, Microsoft MVP: Enterprise Client Management
# Blog: http://www.ronnipedersen.com
# Twitter: @ronnipedersen
# Date: 02/02-2015
# -------------------------------------------------------------------

# Connect to the ConfigMgr Site.
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
CD P02:

# Create Update Schedules for the collections
$Schedule = New-CMSchedule -Start "01/01/2015 9:00 PM" -DayOfWeek Sunday -RecurCount 1

# Create Device Collections for SCCM Client Versions
New-CMDeviceCollection -Name "#CLI - Client Version = 5.00.7958.1000 (2012 R2 RTM)" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CLI - Client Version = 5.00.7958.1203 (2012 R2 CU1)" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CLI - Client Version = 5.00.7958.1303 (2012 R2 CU2)" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CLI - Client Version = 5.00.7958.1401 (2012 R2 CU3)" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CLI - Client Version = 5.00.7958.1501 (2012 R2 CU4)" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic

# Add Query Rules for Client Version Device Collections
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CLI - Client Version = 5.00.7958.1000 (2012 R2 RTM)" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1000'" -RuleName "Client Version = 5.00.7958.1000"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CLI - Client Version = 5.00.7958.1203 (2012 R2 CU1)" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1203'" -RuleName "Client Version = 5.00.7958.1203"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CLI - Client Version = 5.00.7958.1303 (2012 R2 CU2)" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1303'" -RuleName "Client Version = 5.00.7958.1303"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CLI - Client Version = 5.00.7958.1401 (2012 R2 CU3)" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1401'" -RuleName "Client Version = 5.00.7958.1401"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CLI - Client Version = 5.00.7958.1501 (2012 R2 CU4)" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System where SMS_R_System.ClientVersion = '5.00.7958.1501'" -RuleName "Client Version = 5.00.7958.1501"

# Create Device Collections for x64 SCCM Clients that needs a specific CU Update
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU1 for x64 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU2 for x64 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU3 for x64 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU4 for x64 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic

# Create Device Collections for x86 SCCM Clients that needs a specific CU Update
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU1 for x86 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU2 for x86 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU3 for x86 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic
New-CMDeviceCollection -Name "#CU - Cumulative Update - ConfigMgr 2012 R2 CU4 for x86 Clients" -LimitingCollectionName "All Desktop and Server Clients" -RefreshSchedule $Schedule -RefreshType Periodic

#Add Query Rules for x64 CU Update Device Collections
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU1 for x64 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X64-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1203' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU1 for x64 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU2 for x64 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X64-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1303' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU2 for x64 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU3 for x64 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X64-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1401' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU3 for x64 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU4 for x64 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X64-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1501' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU4 for x64 Clients"

#Add Query Rules for x86 CU Update Device Collections
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU1 for x86 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X86-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1203' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU1 for x86 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU2 for x86 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X86-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1303' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU2 for x86 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU3 for x86 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X86-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1401' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU3 for x86 Clients"
Add-CMDeviceCollectionQueryMembershipRule -CollectionName "#CU - Cumulative Update - ConfigMgr 2012 R2 CU4 for x86 Clients" -QueryExpression "select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from SMS_R_System inner join SMS_G_System_SYSTEM on SMS_G_System_SYSTEM.ResourceID = SMS_R_System.ResourceId where SMS_R_System.Active = '1' and SMS_G_System_SYSTEM.SystemType = 'X86-based PC' and SMS_R_System.ClientVersion < '5.00.7958.1501' and SMS_R_System.ClientVersion >= '5.00.7958.1000' order by SMS_R_System.Name" -RuleName "SCCM 2012 R2 CU4 for x86 Clients"
