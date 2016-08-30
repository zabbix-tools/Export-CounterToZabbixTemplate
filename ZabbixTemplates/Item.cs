namespace ZabbixTemplates
{
    using System.Collections.Generic;

    public class Item
    {
        public Item()
        {
            Applications = new ApplicationSet();
        }

        private int _delay = 60;
        private int _history = 7;
        private int _trends = 365;

        public string Name { get; set; }
        public string Description { get; set; }
        public ItemType ItemType { get; set; }
        public string Key { get; set; }
        public ItemStatus Status { get; set; }
        public ApplicationSet Applications { get; protected set; }

        public int Delay
        {
            get { return _delay; }
            set { _delay = value; }
        }

        public int History
        {
            get { return _history; }
            set { _history = value; }
        }

        public int Trends 
        {
            get { return _trends; }
            set { _trends = value; }
        }
    }

    public class ItemCollection : List<Item> {
        public ItemCollection() : base() { }
    }


    public enum ItemType {
        ZabbixAgent = 0,
        ZabbixAgentActive = 7
    }

    public enum ItemStatus
    {
        Enabled = 0,
        Disabled = 1,
    }
}
