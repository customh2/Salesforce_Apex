global class ScheduleFetchWebsiteOrdersBatch implements Database.Batchable<WebsiteControl__c>, Database.AllowsCallouts {
	
	global List<WebsiteControl__c> ctlList {get; set;}
	global String OrderNumber {get; set;}

    //global Database.QueryLocator start(Database.BatchableContext BC) {
    //	system.Debug(' -- BATCH -- start() called');
    //    String query = 'SELECT Id,Name FROM WebsiteControl__c';
    //    return Database.getQueryLocator(query);
    //}

	global Iterable<WebsiteControl__c> start(database.batchablecontext BC) {
		system.Debug(' -- BATCH -- start() called');
		ctlList = [SELECT Id, Name FROM WebsiteControl__c WHERE WebsiteOrderDownloadEnable__c = true];
		return (ctlList);
	} 
    
    global void execute(Database.BatchableContext BC, List<WebsiteControl__c> scope) {
		system.Debug(' -- BATCH -- execute() function called');
        ScheduleFetchWebsiteOrders Sched = new ScheduleFetchWebsiteOrders();
        Sched.OrderNumber = OrderNumber;
        //Sched.GetOrders(OrderNumber);
        Sched.GetOrders();
        /*
		for (WebsiteControl__c ctl : scope) {
			system.Debug(' -- BATCH -- execute() function proccessing ' + ctl.Name);
            ScheduleFetchWebsiteOrders Sched = new ScheduleFetchWebsiteOrders();
        	Sched.GetOrders();
		}
		*/
		system.Debug(' -- BATCH -- execute() function ending');
    }  
    global void finish(Database.BatchableContext BC) {
    	system.Debug(' -- BATCH -- finish() called');
    }
}