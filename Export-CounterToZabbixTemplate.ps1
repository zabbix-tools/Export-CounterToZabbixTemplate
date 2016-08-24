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
    # [Microsoft.PowerShell.Commands.GetCounter.CounterSet[]] # Breaks PSv3+
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)] 
    [Alias('PsPath')]
    [String[]] $CounterSet       = $null,
    [String]   $ComputerName     = ".",
    [String]   $InstanceName     = [System.String]::Empty,
    [String]   $TemplateName     = [System.String]::Empty,
    [String]   $TemplateGroup    = "Templates",
    [Int]      $CheckDelay       = 300,
    [Int]      $DiscoveryDelay   = 3600,
    [Int]      $HistoryRetention = 365,
    [Int]      $TrendsRetention  = 3650,
    [Switch]   $EnableItems,
    [Switch]   $ActiveChecks
);

Begin {
    $counterSets = @();

    # Make sure CounterSet names, a CounterSet filter or piped CounterSet objects have been given
    # TODO: Use parameter sets instead
    if ( $PSCounterSets -eq $null -and[System.String]::IsNullOrEmpty($CounterSet) ) {
        Throw "Missing an argument to parameter 'CounterSet'. Specify a parameter of type 'System.String[]' and try again."
    }
}

Process {
    # Populate the $counterSets array with .Net PerformanceCounterCategories
    # If no CounterSets were piped, and the user specified a filter:
    if( $PSCounterSets -Eq $null -And ![System.String]::IsNullOrEmpty($CounterSetFilter) ) {
        $PSCounterSets = Get-Counter -ComputerName $ComputerName -ListSet $CounterSetFilter -ErrorAction Stop
    }
    
    # If CounterSets were piped or a Filter was successfully fetched, convert to .Net objects
    if( $PSCounterSets -ne $null ) {
        # Take a PS GetCounter.CounterSet array and convert them .Net PerformanceCounterCategories
        foreach($PSCounterSet in $PSCounterSets) {
            $counterSets += New-Object -TypeName System.Diagnostics.PerformanceCounterCategory -ArgumentList $PSCounterSet.CounterSetName, $ComputerName
        }
    }
    
    # Fetch CounterSet straight from .Net as specified in -CounterSetNames
    elseif( $CounterSetNames -ne $null ) {
        foreach($CounterSetName in $CounterSetNames) {
            if([System.Diagnostics.PerformanceCounterCategory]::Exists($CounterSetName)) {
                $counterSets += New-Object -TypeName System.Diagnostics.PerformanceCounterCategory -ArgumentList $CounterSetName, $ComputerName
            } else {
                Throw "Counter Set '$CounterSetName' not found.";
            }
        }
    }
    
}

End {
    Function Add-BaseItemDefaults {
        param(
            [Parameter(ValueFromPipeline = $true, Position = 0)]
            [System.Xml.XmlNode]
            $node
        );
        
        # Common values for Items, Item Prototypes and Discovery Rules
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
    }
    
    Function Add-ItemDefaults($node) {
        Add-BaseItemDefaults($node);
    
        # Default values for standard Template Items
        $node.AppendChild($xDoc.CreateElement("data_type")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("delay")).InnerText = $CheckDelay
        $node.AppendChild($xDoc.CreateElement("delta")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("formula")).InnerText = 1
        $node.AppendChild($xDoc.CreateElement("history")).InnerText = $HistoryRetention
        $node.AppendChild($xDoc.CreateElement("inventory_link")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("multiplier")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("trends")).InnerText = $TrendsRetention
        $node.AppendChild($xDoc.CreateElement("units"))
        $node.AppendChild($xDoc.CreateElement("value_type")).InnerText = 0
        $node.AppendChild($xDoc.CreateElement("valuemap"))
    }
    
    Function Add-DiscoveryRuleDefaults($node) {
        Add-BaseItemDefaults($node);
        
        # Default values for Discovery Rules
        $node.AppendChild($xDoc.CreateElement("delay")).InnerText = $DiscoveryDelay
        $node.AppendChild($xDoc.CreateElement("filter")).InnerText = ":"
        $node.AppendChild($xDoc.CreateElement("lifetime")).InnerText = "30"
    }
    
    Function Add-ItemUnits {
        param(
            [Parameter(ValueFromPipeline = $true, Position = 0)]
            [System.Xml.XmlNode]
            $node,
            
            [System.String]
            $counterName,

            [System.String]
            $counterHelp
        );
        
        # Determine unit type by stirng match
        if($counterName -match "^% ") { $units = "%" }
        elseif($counterName -match "%") { $units = "%" }
        elseif($counterName -match "Elapsed Time") { $units = "s" }
        elseif($counterName -match "Working Set") { $units = "B" }
        elseif($counterName -match "Commit Limit") { $units = "B" }
        elseif($counterName -match "TBytes/sec") { $units = "MBps" }
        elseif($counterName -match "TB/sec") { $units = "MBps" }
        elseif($counterName -match "GBytes/sec") { $units = "GBps" }
        elseif($counterName -match "GB/sec") { $units = "GBps" }
        elseif($counterName -match "MBytes/sec") { $units = "MBps" }
        elseif($counterName -match "MB/sec") { $units = "MBps" }
        elseif($counterName -match "KBytes/sec") { $units = "KBps" }
        elseif($counterName -match "KB/sec") { $units = "KBps" }
        elseif($counterName -match "Bytes/sec") { $units = "Bps" }
        elseif($counterName -match "B/sec") { $units = "Bps" }
        elseif($counterName -match "TBytes") { $units = "TB" }
        elseif($counterName -match "GBytes") { $units = "GB" }
        elseif($counterName -match "MBytes") { $units = "MB" }
        elseif($counterName -match "KBytes") { $units = "KB" }
        elseif($counterName -match "Bytes") { $units = "B" }
        elseif($counterName -match "\(s\)") { $units = "s" }
        elseif($counterName -match "\(sec\)") { $units = "s" }
        elseif($counterName -match "sec/") { $units = "s" }
        else { $units = [System.String]::Empty }

        # If the help contains "in milliseconds", "of milliseconds", "in msec", "of msec", "(msec)" then convert to seconds
        if($counterHelp -match "in milliseconds" -Or $counterHelp -match "of milliseconds" -Or $counterHelp -match "in msec" -Or $counterHelp -match "of msec" -Or $counterHelp -match "(msec)") { $units = "s" }
        if($counterHelp -match "in milliseconds" -Or $counterHelp -match "of milliseconds" -Or $counterHelp -match "in msec" -Or $counterHelp -match "of msec" -Or $counterHelp -match "(msec)") { $node.SelectSingleNode('description').InnerText = $counterHelp + "`n`nZabbix: Converted Milliseconds To Seconds" }
        if($counterHelp -match "in milliseconds" -Or $counterHelp -match "of milliseconds" -Or $counterHelp -match "in msec" -Or $counterHelp -match "of msec" -Or $counterHelp -match "(msec)") { $node.SelectSingleNode('formula').InnerText = 0.001 }
        if($counterHelp -match "in milliseconds" -Or $counterHelp -match "of milliseconds" -Or $counterHelp -match "in msec" -Or $counterHelp -match "of msec" -Or $counterHelp -match "(msec)") { $node.SelectSingleNode('multiplier').InnerText = 1 }

        # If the name contains "in milliseconds", "of milliseconds", "in msec", "of msec", "(msec)" then convert to seconds
        if($counterName -match "in milliseconds" -Or $counterName -match "of milliseconds" -Or $counterName -match "in msec" -Or $counterName -match "of msec" -Or $counterName -match "(msec)") { $units = "s" }
        if($counterName -match "in milliseconds" -Or $counterName -match "of milliseconds" -Or $counterName -match "in msec" -Or $counterName -match "of msec" -Or $counterName -match "(msec)") { $node.SelectSingleNode('description').InnerText = $counterHelp + "`n`nZabbix: Converted Milliseconds To Seconds" }
        if($counterName -match "in milliseconds" -Or $counterName -match "of milliseconds" -Or $counterName -match "in msec" -Or $counterName -match "of msec" -Or $counterName -match "(msec)") { $node.SelectSingleNode('formula').InnerText = 0.001 }
        if($counterName -match "in milliseconds" -Or $counterName -match "of milliseconds" -Or $counterName -match "in msec" -Or $counterName -match "of msec" -Or $counterName -match "(msec)") { $node.SelectSingleNode('multiplier').InnerText = 1 }
    
        $node.SelectSingleNode('units').InnerText = $units;
        
    }
    
    # Zabbix Agent (Active) = 7, Zabbix Agent = 0
    if($ActiveChecks) { $itemType = 7 } else { $itemType = 0 }

    # Default item status
    if($EnableItems) { $itemStatus = 0 } else { $itemStatus = 1 }
    
    # Template creation date
    $date = Get-Date -Format u
    
    # Use an Instance Name or Item Discovery?
    $useInstanceName = ![String]::IsNullOrEmpty($InstanceName);

    # Build a list of template applications to be added
    $applications = @();
    
    # Note to be added to all discovery rules
    $discoveryNote = @"


* Note *
This discovery rule requires the 'perf_counter.discovery[]' key to be configured on the remote agent to execute the 'Get-CounterSetInstances.ps1' PowerShell script.
"@;

    # Create XML Document and root nodes
    [System.XML.XMLDocument] $xDoc = New-Object System.XML.XMLDocument;
    $xDoc.CreateXmlDeclaration("1.0", "UTF-8", $null);
    $xDoc.LoadXml(@"
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
"@);

    # Get template node and set name
    $templateNode     = $xDoc.SelectSingleNode("/zabbix_export/templates/template");
    $applicationsNode = $templateNode.SelectSingleNode("applications");
    $itemsNode        = $templateNode.SelectSingleNode("items");
    $discRulesNode    = $templateNode.SelectSingleNode("discovery_rules");
    $macrosNode       = $templateNode.SelectSingleNode("macros");
    
    # Parse counters as items
    $includedSets = @();
    foreach($counterSet in $counterSets) {
        $includedSets += $counterSet.CategoryName;
        
        # Add a Template Application for this set
        if($useInstanceName) {
            $appname   = $counterSet.CategoryName + ' (' + $InstanceName + ')';
            $macroName = $counterSet.CategoryName.ToUpper() -replace '\s+', '_';
        } else {
            $appName   = $counterSet.CategoryName
        }

        $applications += $appName;

        # Single instance counters are simply Template Items and don't require discovery
        if($counterSet.CategoryType -eq "SingleInstance" -or $useInstanceName) {
            $items = @{};
            $counters = @();
            $counters = $counterSet.GetCounters();

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
                Add-ItemDefaults($itemNode);

                # Derived Values
                $itemNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter[""\" + $items[$item]["CounterSet"] + "\" + $items[$item]["CounterName"] + """]"
                $itemNode.AppendChild($xDoc.CreateElement("name")).InnerText = $items[$item]["CounterSet"] + " - " + $items[$item]["CounterName"]
                $itemNode.AppendChild($xDoc.CreateElement("description")).InnerText = $items[$item]["CounterHelp"]
                
                # Add unit type
                Add-ItemUnits -node $itemNode -counterName $items[$item]["CounterName"] -counterHelp $items[$item]["CounterHelp"];
                
                # Add item to Application
                $itemNode.AppendChild($xDoc.CreateElement("applications"));
                $voidNode.AppendChild($xDoc.CreateElement("application"));
                $voidNode.AppendChild($xDoc.CreateElement("name")).InnerText = $appName;
                
                # Append item
                $itemNode = $itemsNode.AppendChild($itemNode);
                
            }
            
        }
        
        # MultiInstance Counter Categories require discovery rules (lets only parse the first one)
        elseif($counterSet.CategoryType -eq "MultiInstance") {

            # Create empty list for items
            $items = @{};

            # Get counter sets instances
            $instances = $counterSet.GetInstanceNames();

            # If there are instances
            if($instances) {

                # For every instance
                foreach($instance in $instances) {

                    # Create a list of .Net Counters
                    $counters = @();

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
                $counters = @();

                # Get the counters for the instance
                $counters = $counterSet.GetCounters();

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
            $discNode = $xDoc.CreateElement("discovery_rule");
            Add-DiscoveryRuleDefaults($discNode);
            
            # Derived Values for discovery rule
            $discNode.AppendChild($xDoc.CreateElement("name")).InnerText = $counterSet.CategoryName + " Performance Counter Discovery";
            $discNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter.discovery[" + $counterSet.CategoryName + "]";
            $discNode.AppendChild($xDoc.CreateElement("description")).InnerText = $counterSet.CategoryHelp + $discoveryNote;

            # Create prototype for each counter in this set
            $discItemProtosNode = $discNode.AppendChild($xDoc.CreateElement("item_prototypes"));

            # For every item
            foreach ($item in $items.keys) {
            
                $protoItemNode = $xDoc.CreateElement("item_prototype")      
                Add-ItemDefaults($protoItemNode);

                # Derived Values
                $protoItemNode.AppendChild($xDoc.CreateElement("key")).InnerText = "perf_counter[""\" + $items[$item]["CounterSet"] + "({#INSTANCE})\" + $items[$item]["CounterName"] + """]"
                $protoItemNode.AppendChild($xDoc.CreateElement("name")).InnerText = $items[$item]["CounterSet"] + " - " + $items[$item]["CounterName"] + " ({#INSTANCE})"
                $protoItemNode.AppendChild($xDoc.CreateElement("description")).InnerText = $items[$item]["CounterHelp"]
                
                # Add unit type
                #Add-ItemUnits -node $protoItemNode -counterName $counter.CounterName -counterHelp $counter.CounterHelp;
                Add-ItemUnits -node $protoItemNode -counterName $items[$item]["CounterName"] -counterHelp $items[$item]["CounterHelp"];
                
                # Add item to Application
                $protoItemNode.AppendChild($xDoc.CreateElement("applications"));
                $voidNode.AppendChild($xDoc.CreateElement("application"));
                $voidNode.AppendChild($xDoc.CreateElement("name")).InnerText = $appName;
                
                $protoItemNode = $discItemProtosNode.AppendChild($protoItemNode);

            }
            
            # Append discovery rule
            $discNode = $discRulesNode.AppendChild($discNode)

        }

    }
    
    # Add applications to template
    foreach($application in $applications) {
        $applicationsNode.AppendChild($xDoc.CreateElement("application"));
        $voidNode.AppendChild($xDoc.CreateElement("name")).InnerText = $application;
    }
    
    # Add list of counter sets as a macro (Removed as most times the value for the macro was too long, and the set can be obtained by the application name)
    #$macroNode = $macrosNode.AppendChild($xDoc.CreateElement("macro"));
    #$macroNode.AppendChild($xDoc.CreateElement("macro")).InnerText = "{`$COUNTER_SETS}";
    #$macroNode.AppendChild($xDoc.CreateElement("value")).InnerText = '"' + ([String]::Join('","', $includedSets)) + '"';
    
    # Add instance name macro (Removed as most times the value for the macro was too long, and the set can be obtained by the application name)
    #if($useInstanceName) {
        #$macroNode = $macrosNode.AppendChild($xDoc.CreateElement("macro"));
        #$macroNode.AppendChild($xDoc.CreateElement("macro")).InnerText = '{$' + $macroName + '}';
        #$macroNode.AppendChild($xDoc.CreateElement("value")).InnerText = $InstanceName;
    #}
    
    # Set template name
    if([System.String]::IsNullOrEmpty($TemplateName)) {
        if($ComputerName -eq '.') { $hostname = hostname } else { $hostname = $ComputerName }
        $TemplateName = 'Template Performance Counters from ' + $hostname;
    }
    $templateNode.SelectSingleNode("name").InnerText = $TemplateName
    $templateNode.SelectSingleNode("template").InnerText = $TemplateName
    
    # Create an output stream
    [System.IO.StringWriter] $stream = New-Object System.IO.StringWriter

    # Save the XML with pretty formatting to the stream
    $xDoc.Save($stream);
    $stream.Close();
    
    # Output to console or next command in a pipeline
    Write-Output $stream.ToString();
}
