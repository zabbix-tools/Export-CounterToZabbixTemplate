<#PSScriptInfo
.SYNOPSIS
Exports Windows Performance Counters into a valid Zabbix Template XML declaration which may be imported for the monitoring of Windows performance data.
Pipe to Out-File to save the generated XML data to file.

.DESCRIPTION
The Convert-PerfCountersToZabbixTemplate script does... TODO

.NOTES
To see all available CounterSets on a system:
Get-Counter -ListSet * | Select-Object CounterSetName

Todo List:
- Add graph templating
- Add consideration of Instance Lifetime when discovering instance counters
- Validate that all instance contain all instance counters
- Validate support for instance names with nonstandard chars (spaces, etc)

.EXAMPLE
Convert all available Performance Counters on the local system to an XML Zabbix Template

./Convert-PerfCountersToZabbixTemplate.ps1 | Out-File template.xml

.EXAMPLE
Pipe all available Counter Sets on the local system into an XML Zabbix Template

Get-Count -ListSet * | ./Convert-PerfCountersToZabbixTemplate.ps1 | Out-File template.xml

.EXAMPLE
Create a template to monitor the 'explorer' process on a system

./Convert-PerfCountersToZabbixTemplate.ps1 -CounterSetNames Process -InstanceName explorer

.PARAMETER PSCounterSets
Sets the Performance Counters Sets to be converted to a Zabbix Template XML document. If not defined, the Filter parameter is used instead to gather Counter Sets.

.PARAMETER CounterSetFilter
Gets the specified performance counter sets on the computers. Enter the names of the counter sets. Wildcards are permitted.
This parameter is ignored if the -PSCounterSets parameter is specified.

.PARAMETER CounterSetNames
Sets the specified performance counter set on the computer. Command Separated List. Wilcards are NOT permitted.
This parameter is ignored if the -PSCounterSets or -CounterSetFilter parameter is specified.

.PARAMETER ComputerName
Gets data from the specified computers. Type the NetBIOS name, an Internet Protocol (IP) address, or the fully qualified domain names of the computers. The default value is the local computer.
All Template Items generated will use local host '.', not the remote computer from which the performance counters were discovered.

Note: Get-Counter does not rely on Windows PowerShell remoting. You can use the ComputerName parameter of Get-Counter even if your computer is not configured for remoting in Windows PowerShell.

.PARAMETER InstanceName
Sets the name of a Performance Counter instance explicitely; to be queried for a multi-instance counter set. This prevents discovery rules from being created to discover all available instances for a counter.

.PARAMETER TemplateName
Sets the name of Zabbix Template generated.

.PARAMETER TemplateGroup
Sets the name of the Hostgroup to which the Zabbix Template will be added.

.PARAMETER EnableItems
Sets whether of not Template Items, Discovery Rules and Item Prototypes will be enabled by default.

.PARAMETER CheckDelay
Sets the check interval delay of all Template Items and Item Prototypes in seconds.

.PARAMETER DiscoveryDelay
Sets the discovery interval delay of all Template Discovery Rules in seconds.

.PARAMETER HistoryRetention
Sets the history retention time of all Items and Item Prototypes in days.

.PARAMETER TrendsRetention
Sets the Trends History retention time of all Items and Item prototypes in days.

.PARAMETER ActiveChecks
Sets whether Template Items and Item Prototypes will use the Zabbix Agent (Active) Item type.

#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)] 
    [String[]]  $CounterSets      = $null,

    [String]    $ComputerName     = ".",
    [String]    $InstanceName     = [System.String]::Empty,
    [String]    $TemplateName     = [System.String]::Empty,
    [String]    $TemplateGroup    = "Templates",
    [Int]       $CheckDelay       = 60,
    [Int]       $DiscoveryDelay   = 3600,
    [Int]       $HistoryRetention = 7,
    [Int]       $TrendsRetention  = 365,
    [Switch]    $EnableItems      = $true,
    [Switch]    $ActiveChecks     = $true
)

Begin {
    # Zabbix Agent (Active) = 7, Zabbix Agent = 0
    if($ActiveChecks) { $itemType = 7 } else { $itemType = 0 }

    # Default item status
    if($EnableItems) { $itemStatus = 0 } else { $itemStatus = 1 }
    
    # Template creation date
    $date = Get-Date -Format u
    
    # Use an Instance Name or Item Discovery?
    $useInstanceName = ![String]::IsNullOrEmpty($InstanceName)

    # Build a list of template applications to be added
    $applications = @()
    
    # Note to be added to all discovery rules
    $discoveryNote = @"


* Note *
This discovery rule requires the 'perf_counter.discovery[]' key to be configured on the remote agent to execute the 'Get-CounterSetInstances.ps1' PowerShell script.
"@

    # Create XML Document and root nodes
    [System.XML.XMLDocument] $xDoc = New-Object System.XML.XMLDocument
    $xDoc.LoadXml(@"
<?xml version="1.0" encoding="UTF-8" ?>
<zabbix_export>
    <version>2.0</version>  
    <date>$date</date>
    <graphs />
    <groups>
        <group>
            <name>$TemplateGroup</name>
        </group>
    </groups>
    <templates>
        <template>
            <template></template>
            <name></name>
            <applications />
            <discovery_rules />
            <groups>
                <group>
                    <name>$TemplateGroup</name>
                </group>
            </groups>
            <items />
            <macros />
            <screens />
        </template>
    </templates>
    <triggers />
</zabbix_export>
"@)

    # Get template node and set name
    $templateNode     = $xDoc.SelectSingleNode("/zabbix_export/templates/template")
    $applicationsNode = $templateNode.SelectSingleNode("applications")
    $itemsNode        = $templateNode.SelectSingleNode("items")
    $discRulesNode    = $templateNode.SelectSingleNode("discovery_rules")
    $macrosNode       = $templateNode.SelectSingleNode("macros")
}

Process {
    function New-BaseItemNode {
        <#
            .Synopsis
                Creates an XML node with children common to Items, Discovery Rules and Item Prorotypes.
        #>
        [OutputType([System.Xml.XmlElement])]
        Param(
            [Parameter(Position = 0, Mandatory = $true)]
            [String] $Name
        )

        $node = $xDoc.CreateElement($Name)

        # Common values for Items, Item Prototypes and Discovery Rules
        [void](
        $node.AppendChild($xDoc.CreateElement("allowed_hosts"))
        $node.AppendChild($xDoc.CreateElement("authtype")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("delay_flex"))
        $node.AppendChild($xDoc.CreateElement("ipmi_sensor"))
        $node.AppendChild($xDoc.CreateElement("params"))
        $node.AppendChild($xDoc.CreateElement("password"))
        $node.AppendChild($xDoc.CreateElement("port"))
        $node.AppendChild($xDoc.CreateElement("privatekey"))
        $node.AppendChild($xDoc.CreateElement("publickey"))
        $node.AppendChild($xDoc.CreateElement("snmp_community"))
        $node.AppendChild($xDoc.CreateElement("snmp_oid"))
        $node.AppendChild($xDoc.CreateElement("snmpv3_authpassphrase"))
        $node.AppendChild($xDoc.CreateElement("snmpv3_authprotocol")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("snmpv3_contextname"))
        $node.AppendChild($xDoc.CreateElement("snmpv3_privpassphrase"))
        $node.AppendChild($xDoc.CreateElement("snmpv3_privprotocol")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("snmpv3_securitylevel")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("snmpv3_securityname"))
        $node.AppendChild($xDoc.CreateElement("status")).InnerText = $itemStatus
        $node.AppendChild($xDoc.CreateElement("type")).InnerText = $itemType
        $node.AppendChild($xDoc.CreateElement("username"))
        )

        return $node
    }

    # Append Performance Counter Sets to the XML document
    foreach ($counterSet in $CounterSets) {
        # Fetch .Net PerformanceCounterCategory for the given counter set. We use .Net objects instead of the the
        # objects returned by Get-Counter for two reasons: the .Net objects include help information and
        # Get-Counter has not been implemented on Server 2016 Nano.
        if ([System.Diagnostics.PerformanceCounterCategory]::Exists($counterSet)) {
            $pdhCategory = New-Object -TypeName System.Diagnostics.PerformanceCounterCategory -ArgumentList $counterSet, $ComputerName
        } else {
            throw "Counter Set '$counterSet' no found."
        }

        # Compute application name
        if($useInstanceName) {
            $appname = $counterSet.CategoryName + ' (' + $InstanceName + ')'
        } else {
            $appName = $counterSet.CategoryName
        }

        # append a single instance counter set
        if($pdhCategory.CategoryType -eq "SingleInstance" -or $useInstanceName) {
            foreach ($pdhCounter in $pdhCategory.GetCounters()) {
                $itemNode = New-BaseItemNode -Name "item"

                <#

                # Derived Values
                $itemNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter[""\" + $pdhCategory.CategoryName + "\" + $pdhCounter.CounterName + """]"
                
                
                
                $itemNode.AppendChild($xDoc.CreateElement("name")).
                    InnerText = $items[$item]["CounterSet"] + " - " + $items[$item]["CounterName"]

                $itemNode.AppendChild($xDoc.CreateElement("description")).
                    InnerText = $items[$item]["CounterHelp"]

                # Add item to Application
                $itemNode.AppendChild($xDoc.CreateElement("applications")).AppendChild($xDoc.CreateElement("application")).AppendChild($xDoc.CreateElement("name")).InnerText = $appName

                #>

                # Append item
                $itemsNode.AppendChild($itemNode);

            }
        }

        # append application
        $applications += $pdhCategory.CategoryName
    }
}

End {    
    # Set template name
    if([System.String]::IsNullOrEmpty($TemplateName)) {
        if($ComputerName -eq '.') { $hostname = hostname } else { $hostname = $ComputerName }
        $TemplateName = 'Template Performance Counters from ' + $hostname;
    }

    $templateNode.SelectSingleNode("name").InnerText = $TemplateName
    $templateNode.SelectSingleNode("template").InnerText = $TemplateName

    # Add applications to template
    foreach($application in $applications) {
        $applicationsNode.
            AppendChild($xDoc.CreateElement("application")).
            AppendChild($xDoc.CreateElement("name")).
            InnerText = $application
    }
    
    # Create an output stream
    [System.IO.StringWriter] $stream = New-Object System.IO.StringWriter

    # Save the XML with pretty formatting to the stream
    $xDoc.Save($stream);
    $stream.Close();
    
    # Output to console or next command in a pipeline
    Write-Output $stream.ToString();
}
