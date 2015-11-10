/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* ScheduleFetchWebsiteOrdersSched - Class to Fetch Website Orders  *
* This class is called by the cron scheduler, which will call the  *
* ScheduleFetchWebsiteOrders.GetOrders() method (@future) which    *
* will perform the HTTPRequest Callout. The test class will set    *
* the Test.setMock() to use the Mock HTTPRequest Callout (because  *
* HTTPRequest is not permitted normally in Scheduled classes).     *
* Written By: Kim A. Kitchen, Performance Depot Inc.               *
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

global with sharing class ScheduleFetchWebsiteOrdersSched implements Schedulable {
	global String OrderNumber {get; set;}
	
	global void execute(SchedulableContext ctx) {
		system.Debug(' -- SCHED -- execute() function called (OrderNUmber ' + OrderNumber + ')');
        //ScheduleFetchWebsiteOrders.GetOrders();
		ScheduleFetchWebsiteOrdersBatch batch = new ScheduleFetchWebsiteOrdersBatch();
		batch.OrderNumber = OrderNumber;
		//batch.ctlList = [SELECT Id, Name FROM WebsiteControl__c WHERE WebsiteOrderDownloadEnable__c = true];
		system.debug(' -- SCHED -- Batch created, executing batch ...');
		DataBase.executeBatch(batch,1);
		system.Debug(' -- SCHED -- execute() function ending');
	}	
}