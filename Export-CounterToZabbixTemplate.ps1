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
[Alias("Export-CounterToZabbixTemplate")]
#[OutputType([String])]
param(
    [Parameter(ParameterSetName = "FromCounterSet", Position = 0, Mandatory = $true, ValueFromPipeline = $true)] 
    [Microsoft.Powershell.Commands.GetCounter.CounterSet]
    $PSCounterSet = $null,

    [Parameter(ParameterSetName = "FromCounterSetName", Position = 0, Mandatory = $true, ValueFromPipeline = $true)] 
    [String[]]
    $CounterSet   = $null,

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
    Function Export-PSCounterSet {
        param(
            [Parameter(ValueFromPipeline = $true, Position = 0)]
            [System.Xml.Node] $XmlNode

            [Parameter(Position = 1)]
            $CounterSet
        )

        # TODO: check .Net counter set exists with[System.Diagnostics.PerformanceCounterCategory]::Exists
        $dotnetCounterSet = New-Object -TypeName System.Diagnostics.PerformanceCounterCategory -ArgumentList $set.CounterSetName, $ComputerName
        

    }

    # if counter set name/s were given as strings
    if ($PSCounterSet -eq $null) {
        foreach ($cset in $CounterSet) {
            # use Get-Counter in case the requested set is actually a search pattern recognised by Get-Counter
            $PSCounterSet = Get-Counter -ListSet $cset

            # TODO: error handle on $null

            Export-PSCounterSet -XmlNode -CounterSet $PSCounterSet
        }
        
    } else {
        # counter set objects piped from Get-Counter -ListSet
        foreach($cset in $PSCounterSet) {
            Export-PSCounterSet $cset
        }
    }
}

End {    
    # Parse counters as items
    $includedSets = @()
    foreach($counterSet in $counterSets) {
        $includedSets += $counterSet.CategoryName
        
        # Add a Template Application for this set
        if($useInstanceName) {
            $appname   = $counterSet.CategoryName + ' (' + $InstanceName + ')'
            $macroName = $counterSet.CategoryName.ToUpper() -replace '\s+', '_'
        } else {
            $appName   = $counterSet.CategoryName
        }

        $applications += $appName

        # Single instance counters are simply Template Items and don't require discovery
        if($counterSet.CategoryType -eq "SingleInstance" -or $useInstanceName) {
            $items = @{}
            $counters = @()
            $counters = $counterSet.GetCounters()

            foreach($counter in $counters) {
                # If the counter name is "No name", "Not displayed" or matches the category name then skip the
                # counter. It may be a corrupt performance counter causing duplication within Zabbix.
                # Also skip if the counter has already been added.
                if ( 
                    @( "No name", "Not displayed", $counter.CategoryName ).Contains($counter.CounterName) -or $items.ContainsKey($counter.CounterName)
                ) {
                    Continue
                }

                $items.add($counter.CounterName, @{
                    CounterSet  = $counterSet.CategoryName
                    CounterName = $counter.CounterName
                    CounterHelp = $counter.CounterHelp
                })
            }

            # For every item
            foreach ($item in $items.keys) {
                $itemNode = $xDoc.CreateElement("item")     
                Add-ItemDefaults($itemNode)

                # Derived Values
                $itemNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter[""\" + $items[$item]["CounterSet"] + "\" + $items[$item]["CounterName"] + """]"
                $itemNode.AppendChild($xDoc.CreateElement("name")).InnerText = $items[$item]["CounterSet"] + " - " + $items[$item]["CounterName"]
                $itemNode.AppendChild($xDoc.CreateElement("description")).InnerText = $items[$item]["CounterHelp"]
                
                # Add unit type
                Add-ItemUnits -node $itemNode -counterName $items[$item]["CounterName"] -counterHelp $items[$item]["CounterHelp"]
                
                # Add item to Application
                $itemNode
                    .AppendChild($xDoc.CreateElement("applications"))
                    .AppendChild($xDoc.CreateElement("application"))
                    .AppendChild($xDoc.CreateElement("name")).InnerText = $appName
                
                # Append item
                $itemNode = $itemsNode.AppendChild($itemNode);                
            }
            
        }
        
        # MultiInstance Counter Categories require discovery rules (lets only parse the first one)
        elseif($counterSet.CategoryType -eq "MultiInstance") {

            # Create empty list for items
            $items = @{}

            # Get counter sets instances
            $instances = $counterSet.GetInstanceNames()

            # If there are instances
            if($instances) {

                # For every instance
                foreach($instance in $instances) {

                    # Create a list of .Net Counters
                    $counters = @()

                    # Get the counters for the instance
                    $counters = $counterSet.GetCounters($instance)

                    # For every counter
                    foreach($counter in $counters) {

                        # If the category name is identical to the counter name then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                        if($counter.CounterName -eq $counter.CategoryName) {continue}

                        # If the counter name is "No name" then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                        if($counter.CounterName -eq "No name") {continue}

                        # If the counter name is "Not displayed" then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                        if($counter.CounterName -eq "Not displayed") {continue}

                        # If item defined then skip
                        if($items.ContainsKey($counter.CounterName)) {continue}

                        # Else item not defined then do so
                        else {$items.add($counter.CounterName,@{CounterSet=$counterSet.CategoryName;CounterName=$counter.CounterName;CounterHelp=$counter.CounterHelp})}
                        
                    }
                
                }   

            }

            else {

                # Create a list of .Net Counters
                $counters = @()

                # Get the counters for the instance
                $counters = $counterSet.GetCounters()

                # For every counter
                foreach($counter in $counters) {

                    # If the category name is identical to the counter name then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                    if($counter.CounterName -eq $counter.CategoryName) {continue}

                    # If the counter name is "No name" then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                    if($counter.CounterName -eq "No name") {continue}

                    # If the counter name is "Not displayed" then skip (maybe a corrupt performance counter causing duplication within Zabbix)
                    if($counter.CounterName -eq "Not displayed") {continue}

                    # If item defined then skip
                    if($items.ContainsKey($counter.CounterName)) {continue}

                    # Else item not defined then do so
                    else {

                        $items.add($counter.CounterName,@{CounterSet=$counterSet.CategoryName;CounterName=$counter.CounterName;CounterHelp=$counter.CounterHelp})
                        
                    }
                    
                }
                        
            }

            # Create the discovery rule
            $discNode = $xDoc.CreateElement("discovery_rule")
            Add-DiscoveryRuleDefaults($discNode)
            
            # Derived Values for discovery rule
            $discNode.AppendChild($xDoc.CreateElement("name")).InnerText = $counterSet.CategoryName + " Performance Counter Discovery"
            $discNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter.discovery[" + $counterSet.CategoryName + "]"
            $discNode.AppendChild($xDoc.CreateElement("description")).InnerText = $counterSet.CategoryHelp + $discoveryNote

            # Create prototype for each counter in this set
            $discItemProtosNode = $discNode.AppendChild($xDoc.CreateElement("item_prototypes"))

            # For every item
            foreach ($item in $items.keys) {
            
                $protoItemNode = $xDoc.CreateElement("item_prototype")      
                Add-ItemDefaults($protoItemNode)

                # Derived Values
                $protoItemNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter[""\" + $items[$item]["CounterSet"] + "({#INSTANCE})\" + $items[$item]["CounterName"] + """]"
                $protoItemNode.AppendChild($xDoc.CreateElement("name")).InnerText = $items[$item]["CounterSet"] + " - " + $items[$item]["CounterName"] + " ({#INSTANCE})"
                $protoItemNode.AppendChild($xDoc.CreateElement("description")).InnerText = $items[$item]["CounterHelp"]
                
                # Add unit type
                #Add-ItemUnits -node $protoItemNode -counterName $counter.CounterName -counterHelp $counter.CounterHelp
                Add-ItemUnits -node $protoItemNode -counterName $items[$item]["CounterName"] -counterHelp $items[$item]["CounterHelp"]
                
                # Add item to Application
                $protoItemNode.AppendChild($xDoc.CreateElement("applications"))
                $voidNode.AppendChild($xDoc.CreateElement("application"))
                $voidNode.AppendChild($xDoc.CreateElement("name")).InnerText = $appName
                
                $protoItemNode = $discItemProtosNode.AppendChild($protoItemNode)

            }
            
            # Append discovery rule
            $discNode = $discRulesNode.AppendChild($discNode)

        }

    }
    
    # Add applications to template
    foreach($application in $applications) {
        $applicationsNode.AppendChild($xDoc.CreateElement("application")).
            AppendChild($xDoc.CreateElement("name")).
            InnerText = $application
    }
    
    # Add list of counter sets as a macro (Removed as most times the value for the macro was too long, and the set can be obtained by the application name)
    #$macroNode = $macrosNode.AppendChild($xDoc.CreateElement("macro"))
    #$macroNode.AppendChild($xDoc.CreateElement("macro")).InnerText = "{`$COUNTER_SETS}"
    #$macroNode.AppendChild($xDoc.CreateElement("value")).InnerText = '"' + ([String]::Join('","', $includedSets)) + '"'
    
    # Add instance name macro (Removed as most times the value for the macro was too long, and the set can be obtained by the application name)
    #if($useInstanceName) {
        #$macroNode = $macrosNode.AppendChild($xDoc.CreateElement("macro"))
        #$macroNode.AppendChild($xDoc.CreateElement("macro")).InnerText = '{$' + $macroName + '}'
        #$macroNode.AppendChild($xDoc.CreateElement("value")).InnerText = $InstanceName
    #}
    
    # Set template name
    if([System.String]::IsNullOrEmpty($TemplateName)) {
        if($ComputerName -eq '.') { $hostname = hostname } else { $hostname = $ComputerName }
        $TemplateName = 'Template Performance Counters from ' + $hostname
    }
    $templateNode.SelectSingleNode("name").InnerText = $TemplateName
    $templateNode.SelectSingleNode("template").InnerText = $TemplateName
    
    # Create an output stream
    [System.IO.StringWriter] $stream = New-Object System.IO.StringWriter

    # Save the XML with pretty formatting to the stream
    $xDoc.Save($stream)
    $stream.Close()
    
    # Output to console or next command in a pipeline
    Write-Output $stream.ToString()
}
