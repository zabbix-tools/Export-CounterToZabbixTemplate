namespace ZabbixTemplates
{
    using System;
    using System.IO;
    using System.Text;
    using System.Xml;

    public class TemplateExport
    {
        public TemplateExport()
        {
            Templates = new TemplateCollection();
            Groups = new GroupSet();
        }

        private string _version = "3.0";

        public string Version
        {
            get { return _version; }
            set { _version = value; }
        }

        public string Date { 
            get { return DateTime.UtcNow.ToString(@"yyyy-MM-dd\THH:mm:ss\Z"); }
        }

        public TemplateCollection Templates { get; protected set; }

        public GroupSet Groups { get; protected set; }

        #region Serialization

        public XmlDocument ToXmlDocument()
        {
            // create document
            var doc = new XmlDocument();
            var dec = doc.CreateXmlDeclaration("1.0", "UTF-8", null);
            doc.InsertBefore(dec, doc.DocumentElement);

            // create root
            var root = doc.AppendChild(doc.CreateElement("zabbix_export"));
            root.AppendChild(doc.CreateElement("version")).InnerText = Version;
            root.AppendChild(doc.CreateElement("date")).InnerText = Date;

            // append groups
            var groupsNode = root.AppendChild(doc.CreateElement("groups"));
            foreach (var group in Groups)
            {
                groupsNode.AppendChild(doc.CreateElement("group")).AppendChild(doc.CreateElement("name")).InnerText = group;
            }

            // append templates
            var templatesNode = root.AppendChild(doc.CreateElement("templates"));
            foreach (var template in Templates)
            {
                var templateNode = templatesNode.AppendChild(doc.CreateElement("template"));
                templateNode.AppendChild(doc.CreateElement("template")).InnerText = template.Name;
                templateNode.AppendChild(doc.CreateElement("name")).InnerText = template.Name;
                templateNode.AppendChild(doc.CreateElement("description")).InnerText = template.Description;

                // append template groups
                var templateGroupsNode = templateNode.AppendChild(doc.CreateElement("groups"));
                foreach (var group in template.Groups)
                {
                    templateGroupsNode.AppendChild(doc.CreateElement("group")).AppendChild(doc.CreateElement("name")).InnerText = group;
                }

                // append template applications
                var applicationsNode = templateNode.AppendChild(doc.CreateElement("applications"));
                foreach (var app in template.Applications)
                {
                    applicationsNode.AppendChild(doc.CreateElement("application")).AppendChild(doc.CreateElement("name")).InnerText = app;
                }

                // append template items
                var itemsNode = templateNode.AppendChild(doc.CreateElement("items"));
                foreach (var item in template.Items)
                {
                    var itemNode = itemsNode.AppendChild(doc.CreateElement("item"));

                    itemNode.AppendChild(doc.CreateElement("name")).InnerText = item.Name;
                    itemNode.AppendChild(doc.CreateElement("type")).InnerText = ((int)item.ItemType).ToString();
                    itemNode.AppendChild(doc.CreateElement("key")).InnerText = item.Key;
                    itemNode.AppendChild(doc.CreateElement("delay")).InnerText = item.Delay.ToString();
                    itemNode.AppendChild(doc.CreateElement("history")).InnerText = item.History.ToString();
                    itemNode.AppendChild(doc.CreateElement("trends")).InnerText = item.Trends.ToString();
                    itemNode.AppendChild(doc.CreateElement("status")).InnerText = ((int)item.Status).ToString();

                    // append item applications
                    var itemApplicationsNode = itemNode.AppendChild(doc.CreateElement("applications"));
                    foreach (var app in item.Applications)
                    {
                        itemApplicationsNode.AppendChild(doc.CreateElement("application")).AppendChild(doc.CreateElement("name")).InnerText = app;
                    }
                }
            }

            return doc;
        }

        public void ToXmlStream(StreamWriter w)
        {
            // write doc header
            w.WriteLine(String.Format(
@"<?xml version=""1.0"" encoding=""{0}""?>
<zabbix_export>
    <version>{1}</version>
    <date>{2}</date>
    <groups />
    <templates>", w.Encoding.WebName, Version, Date));

            // write each template
            foreach(var template in Templates)
            {
                w.WriteLine(String.Format(
@"        <template>
            <template>{0}</template>
            <name>{0}</name>
            <description>{1}</description>
        </template>", template.Name, template.Description));
            }
            
            // close templates section
            w.WriteLine("   </templates>");

            // close document
            w.WriteLine("</zabbix_export>");
        }

        public string ToXmlString()
        {
            string result;
            /*

            // write XML data to memory
            using (var m = new MemoryStream()) {
                using (var w = new StreamWriter(m, Encoding.UTF8))
                {
                    ToXmlStream(w);
                    w.Flush();
                    
                    m.Position = 0;
                    using (var r = new StreamReader(m, Encoding.UTF8))
                    {
                        result = r.ReadToEnd();
                    }
                }
            }

            return result;
             * */
            using (var w = new StringWriter()) {
                var doc = ToXmlDocument();
                doc.Save(w);
                result = w.ToString();
            }

            return result;
        }

        #endregion
    }
}
