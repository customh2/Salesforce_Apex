@isTest(SeeAllData=true)
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * This test class tests the ScheduleFetchWebsiteOrders class which fetches orders from the website. *
 * (c) 2015 Performance Depot Inc, Written By: Kim A. Kitchen, Last updated 2015-09-18 (sandbox.kim) *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
public with sharing class ScheduleFetchWebsiteOrdersTest {
   // CRON expression: midnight on March 15.
   // Because this is a test, job executes
   // immediately after Test.stopTest().
   public static String CRON_EXP = '0 0 0 15 3 ? 2022';

	public static testMethod void Testit() {
		// First: tell this test class to use the mock webservice callout (test classes cannot use real callouts)
		Test.setMock(HttpCalloutMock.class, new ScheduleFetchWebsiteOrdersMock());
        
        // Turn debugging on for all websites before testing (otherwize all those debug lines wouldn't be tested)
        //List<WebsiteControl__c> ctls = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c from WebsiteControl__c ];
		//for (WebsiteControl__c Ctl : Ctls) Ctl.WebsiteOrderDebug__c = true;
		//update Ctls;
		
		/* // NOTE: We already have an account and a website control record in both the sandbox and in production 
		   // so we don't need to add them here for testing purposes.
        Account Acct = new Account(Name='HeadlightsDepot2.com');
        insert Acct;
       
       WebsiteControl__c ctl
		// Next, Create a WebsiteControl record
		WebsiteControl__c ctl = new WebsiteControl__c(Name='HeadlightsDepot2.com');
		ctl.WebsiteOrderDownloadMinutes__c = 10;
		ctl.WebsiteOrderLastDownload__c = DateTime.parse('10/14/2011 11:46 AM');
		ctl.WebsiteOrderDownloadEnable__c = true;
		ctl.WebsiteOrderDownloadUsername__c = 'test_user'; // doesn't matter, mock HTTPCallout doesn't authenticate
		ctl.WebsiteOrderDownloadPassword__c = 'test_password'; // not used in test mode
		ctl.WebsiteOrderDownloadURL__c = 'http://www.google.com'; // not used in test mode
		ctl.WebsiteOrderMax__c = 1;
		ctl.WebsiteOrderShipCarrier__c = 'FedEx';
		ctl.WebsiteOrderShipClass__c = 'Home Delivery';
		insert ctl;
		
		*/
		// However: we do need to enable debugging and splitting OrderLines for test code coverage
		// The mock HTTPCallout results contains one order to split orderlines and one that doesn't
		WebsiteControl__c ctl = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c, WebsiteOrderSplitOrderlines__c from WebsiteControl__c LIMIT 1];
		ctl.WebsiteOrderSplitOrderlines__c = true;
		ctl.WebsiteOrderDebug__c = true;
		update ctl;
		
        // Next, create 2 new products to be used in this test
        String SKU = 'TEST-SKU-1';
        String SKU2 = 'TEST-SKU-2';
        datetime now = datetime.now();
        System.debug(' -- TEST (Sched) -- Testing using SKU ' + SKU + '');
        ECS__Product__C product = new ECS__Product__c(Name=SKU, Compatibilities__c='-', FitmentsUpdated__c = true, ECS__Last_Updated__c = now);
        insert product;
        product = new ECS__Product__c(Name=SKU2, Compatibilities__c='-', FitmentsUpdated__c = true, ECS__Last_Updated__c = now);
        insert product;

      	Test.startTest();
      	// Schedule the test job
      	String jobId = System.schedule('ScheduleApexClassTest',CRON_EXP, new ScheduleFetchWebsiteOrdersSched());
         
      	// Get the information from the CronTrigger API object
      	CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

      	// Verify the expressions are the same
      	System.assertEquals(CRON_EXP, ct.CronExpression);

      	// Verify the job has not run
      	System.assertEquals(0, ct.TimesTriggered);

      	// Verify the next time the job will run
      	System.assertEquals('2022-03-15 00:00:00', String.valueOf(ct.NextFireTime));
      	// Test.stopTest() will trigger the scheduled job to run now (regardless of scheduled time)
      	Test.stopTest();

      	// Now that the scheduled job has executed after Test.stopTest(),
      	// check to see that the new order and order_line record(s) exist .
	  	// NOTE: These values are set in the Mock HTTPCallout Class ScheduleFetchWebsiteOrdersMock
		List<ECS__eCommSource_Order__c> orders = [SELECT Id, Name FROM ECS__eCommSource_Order__c];
		
				

	}
}