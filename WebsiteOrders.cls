global with sharing class WebsiteOrders {
    Public String WebsiteControlName;
    public boolean DebugEnable {get; set; }
    public boolean DownloadEnable {get; set;}
    public String DownloadURL {get; set;}
    public String DownloadUsername {get; set;}
    public String DownloadPassword {get; set;}
    public String DownloadMinutes {get; set;}
    public String DownloadMax {get; set;}
    public String OrderShipCarrier {get; set;}
    public String OrderShipClass {get; set;}
    public String LastDownload {get; set;}
    public boolean DebugEnable2 {get; set; }
    public boolean DownloadEnable2 {get; set;}
    public String DownloadURL2 {get; set;}
    public String DownloadUsername2 {get; set;}
    public String DownloadPassword2 {get; set;}
    public String DownloadMinutes2 {get; set;}
    public String DownloadMax2 {get; set;}
    public String OrderShipCarrier2 {get; set;}
    public String OrderShipClass2 {get; set;}
    public String LastDownload2 {get; set;}
    global String OrderNumber {get; set;}
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public WebsiteOrders(ApexPages.StandardController controller) {
        WebsiteControl__c Ctl = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c from WebsiteControl__c LIMIT 1];
        WebsiteControlName = Ctl.Name;
        DebugEnable = Ctl.WebsiteOrderDebug__c;
        DownloadEnable = Ctl.WebsiteOrderDownloadEnable__c;
        DownloadURL = Ctl.WebsiteOrderDownloadURL__c;
        DownloadUsername = Ctl.WebsiteOrderDownloadUsername__c; 
        DownloadPassword = Ctl.WebsiteOrderDownloadPassword__c; 
        DownloadMinutes = String.valueOf(Ctl.WebsiteOrderDownloadMinutes__c);
        DownloadMax = String.valueOf(Ctl.WebsiteOrderMax__c);
        OrderShipCarrier = Ctl.WebsiteOrderShipCarrier__c;
        OrderShipClass = Ctl.WebsiteOrderShipClass__c;
        LastDownload = String.valueOf(Ctl.WebsiteOrderLastDownload__c);
        // make backup copies of these variables
        DebugEnable2 = DebugEnable;
        DownloadEnable2 = DownloadEnable;
        DownloadURL2 = DownloadURL;
        DownloadUsername2 = DownloadUsername; 
        DownloadPassword2 = DownloadPassword; 
        DownloadMinutes2 = DownloadMinutes;
        DownloadMax2 = DownloadMax;
        OrderShipCarrier2 = OrderShipCarrier;
        OrderShipClass2 = OrderShipClass;
        LastDownload2 = LastDownload;
       
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public void fetch_website_orders() {
        
        DateTime OldDate = get_last_order_date();
        //use_temp_settings();
        ScheduleFetchWebsiteOrders Sched = New ScheduleFetchWebsiteOrders();
        try {
            Sched.GetOrders();
            if (Sched.Messages != null) {
            for (String Message : Sched.Messages) debug(Message);
            } else { debug('Sched.Messages is null'); }
        } catch(Exception e) {
            error(e.getMessage());
            if (Sched.Messages != null) {
                error('There are ' + Sched.Messages.Size() + ' Messages:');
                for (String Message : Sched.Messages) error(Message);
            } else { error('Sched.Messages is null'); }
            error(e.getStackTraceString());
        }
        DateTime NewDate = get_last_order_date();
        if (OldDate == NewDate) debug('No New Orders Downloaded.');
        else debug('New Orders were Downloaded.');
        //restore_settings();
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    global void fetch_one_order() {
        // use_temp_settings();
        debug('Fetching ONE ORDER (' + OrderNumber + ')');
        //DateTime OldDate = get_last_order_date();
        ScheduleFetchWebsiteOrders Sched = New ScheduleFetchWebsiteOrders();
        try {
            Sched.OrderNumber = OrderNumber;
            Sched.GetOrders();
            if (Sched.Messages != null) {
            for (String Message : Sched.Messages) debug(Message);
            } else { debug('Sched.Messages is null'); }
        } catch(Exception e) {
            error(e.getMessage());
            if (Sched.Messages != null) {
                error('There are ' + Sched.Messages.Size() + ' Messages:');
                for (String Message : Sched.Messages) error(Message);
            } else { error('Sched.Messages is null'); }
            error(e.getStackTraceString());
        }
        //DateTime NewDate = get_last_order_date();
        //if (OldDate == NewDate) debug('No New Orders Downloaded.');
        //else debug('New Orders were Downloaded.');
        //restore_settings();
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // displays an 'info' message in the pageBlockMessages
    public void debug(string message){
        system.debug(message);
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, message));
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    // displays an 'error' message in the pageBlockMessages
    public void error(string message){
        system.debug(message);
        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, message));
    }
    
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public DateTime get_last_order_date() {
        List<ECS__eCommSource_Order__c> LastOrders = [SELECT Id, Name, ECS__Order_Time__c FROM ECS__eCommSource_Order__c ORDER BY ECS__Order_Time__c DESC NULLS LAST LIMIT 1];
        if (LastOrders.size() > 0) {
            DateTime dt = LastOrders[0].ECS__Order_Time__c;
            return dt;
        } else {
            return null;
        }
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public pageReference WebsiteControls() {
        return new pageReference('/a2p');
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public void use_temp_settings() {
        WebsiteControl__c Ctl = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c from WebsiteControl__c LIMIT 1];
        Ctl.WebsiteOrderDebug__c = DebugEnable;
        Ctl.WebsiteOrderDownloadEnable__c = DownloadEnable;
        Ctl.WebsiteOrderDownloadURL__c = DownloadURL;
        Ctl.WebsiteOrderDownloadUsername__c = DownloadUsername; 
        Ctl.WebsiteOrderDownloadPassword__c = DownloadPassword; 
        Ctl.WebsiteOrderDownloadMinutes__c = integer.valueOf(DownloadMinutes);
        Ctl.WebsiteOrderMax__c = integer.valueOf(DownloadMax);
        Ctl.WebsiteOrderShipCarrier__c = OrderShipCarrier;
        Ctl.WebsiteOrderShipClass__c = OrderShipClass;
        Ctl.WebsiteOrderLastDownload__c = DateTime.valueOf(LastDownload);
        update ctl;
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    public void restore_settings() {
        WebsiteControl__c Ctl = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c from WebsiteControl__c LIMIT 1];
        Ctl.WebsiteOrderDebug__c = DebugEnable2;
        Ctl.WebsiteOrderDownloadEnable__c = DownloadEnable2;
        Ctl.WebsiteOrderDownloadURL__c = DownloadURL2;
        Ctl.WebsiteOrderDownloadUsername__c = DownloadUsername2; 
        Ctl.WebsiteOrderDownloadPassword__c = DownloadPassword2; 
        Ctl.WebsiteOrderDownloadMinutes__c = integer.valueOf(DownloadMinutes2);
        Ctl.WebsiteOrderMax__c = integer.valueOf(DownloadMax2);
        Ctl.WebsiteOrderShipCarrier__c = OrderShipCarrier2;
        Ctl.WebsiteOrderShipClass__c = OrderShipClass2;
        Ctl.WebsiteOrderLastDownload__c = DateTime.valueOf(LastDownload2);
        update ctl;
    }
    // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

}