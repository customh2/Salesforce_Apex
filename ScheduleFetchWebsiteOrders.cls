/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * ScheduleFetchWebsiteOrders - Class to Fetch New Website Orders  *
 * using the Shipworks Generic Module interface (shipworks3.php).  *
 * (c) 2015, Performance Depot, inc, All rights Reserved.          *
 * Written By: Kim A. Kitchen, Performance Depot, Inc.             *
 * Last Modified: 2015-11-03 on Sandbox.sandfull                   *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */

global class ScheduleFetchWebsiteOrders {
    global List<String> Messages = New List<String> {};
    
    global List<SF_Order> SFOrders = new List<SF_Order>();
    
    global List <ECS__Product__c> Products = new List<ECS__Product__c>();
    global List<String> SKUs = new List<String>(); 
    global List<String> Emails = new List<String>(); 
    global List<ECS__Associated_Product__c> Assembly = new List<ECS__Associated_Product__c>();
    global List<ECS__eCommSource_Order__c> UpsertOrders = new List<ECS__eCommSource_Order__c>();
    global List<ECS__Products_Purchased__c> UpsertPurchProd = new List<ECS__Products_Purchased__c>();
    global List<ECS__eCommSource_Order_Line__c> UpsertOrderLines = new List<ECS__eCommSource_Order_Line__c>();
    global List<ECS__Product__c> ProductsToAdd = new List<ECS__Product__c>();
    global List<Contact> UpsertContacts = new List<Contact>();
    global List<ECS__Address__c> UpsertAddresses = new List<ECS__Address__c>();
    global List<ECS__Shipping_Detail__c> UpsertShipDetail = new List<ECS__Shipping_Detail__c>();
    global List<ECS__Payment_Detail__c> UpsertPmtDetail = new List<ECS__Payment_Detail__c>();
    global String OrderNumber = '';
    global boolean do_debug = false;
    
    public integer QueryCount = 0;
	public integer MaxQueries = 50;
    
	//@future(callout=true)
    global ScheduleFetchWebsiteOrders() {
    }
	global void GetOrders() {
		//Debug(' -- CLASS -- ScheduleFetchWebsiteOrders.GetOrders() called');
        DateTime last = DateTime.now();
        DateTime next = DateTime.now();
        
        // the WebsiteControl object has all of the configuration info.  SOQL Query #2
        List<WebsiteControl__c> ctls = [select Name, WebsiteOrderDownloadURL__c, WebsiteOrderDownloadEnable__c, WebsiteOrderDownloadMinutes__c, WebsiteOrderLastDownload__c, WebsiteOrderDownloadUsername__c, WebsiteOrderDownloadPassword__c, WebsiteOrderMax__c, WebsiteOrderShipCarrier__c, WebsiteOrderShipClass__c, WebsiteOrderDebug__c, WebsiteOrderSplitOrderlines__c from WebsiteControl__c ];
        add2count('load website_control records');
		//Debug(' -- CLASS -- (ScheduleFetchWebsiteOrders) ' + ctls.size() + ' Control Records Loaded.');
		
        // Build query and load all of the Accounts
		String AcctsQuery = 'SELECT Id, Name FROM Account';
		Integer i = 0;
		for (WebsiteControl__c ctl : ctls) {
			if (i == 0) AcctsQuery = AcctsQuery + ' WHERE ';
			//else AcctsQuery = AcctsQuery + ' OR ';
			AcctsQuery = AcctsQuery + 'Name = \'' + ctl.Name + '\'';
		}
		List<Account> Accts = database.query(AcctsQuery); // SOQL Query #3
		if (do_debug) system.Debug(' -- CLASS -- (ScheduleFetchWebsiteOrders) ' + Accts.size() + ' Account Records Loaded.');
        
        for (WebsiteControl__c ctl : ctls) {
        	//debug(' -- CLASS -- (ScheduleFetchWebsiteOrders) ctl: ' + ctl);
        	String WebsiteControlName = ctl.Name;
			decimal minutes = ctl.WebsiteOrderDownloadMinutes__c;
	        last = ctl.WebsiteOrderLastDownload__c;
	        Boolean enabled = ctl.WebsiteOrderDownloadEnable__c;
	        String username = ctl.WebsiteOrderDownloadUsername__c;
	        String password = ctl.WebsiteOrderDownloadPassword__c;
            String max_orders = String.valueOf(ctl.WebsiteOrderMax__c);
	        String base = ctl.WebsiteOrderDownloadURL__c + '?username=' + username + '&password=' + password;
            String ShipCarrier = ctl.WebsiteOrderShipCarrier__c;
            String ShipClass = ctl.WebsiteOrderShipClass__c;
            Boolean SplitOrderlines = ctl.WebsiteOrderSplitOrderlines__c;
            do_debug = ctl.WebsiteOrderDebug__c;
            if (ShipCarrier == null) ShipCarrier = 'FedEx';
            if (ShipClass == null) ShipClass = 'Home Delivery';
	        if (max_orders != null) base = base + '&maxcount=' + max_orders;
	        String url = '';
            debug(WebsiteControlName + ' Last Downloaded ' + last);
	        if (last != null) next = last.addMinutes((integer)minutes);
	        
	        if (datetime.Now() >= next && enabled == true) {
	            Http http = new Http();
	 			HttpRequest req = new HttpRequest();
	            req.setMethod('GET');
	            HTTPResponse res;
				Dom.Document doc;
				Dom.XMLNode Shipworks;
				// Get Orders Count
				/*
				url = base + '&action=getcount&start=' + last.format();
	            req.setEndpoint(url);
	            System.debug('url: ' + url);
				HTTPResponse res = http.send(req);
				Dom.Document doc = res.getBodyDocument();
				Dom.XMLNode Shipworks = doc.getRootElement();
	            String CountString = Shipworks.getChildElement('OrderCount', null).getText();
	            integer orderCount = integer.valueOf(CountString);
				*/
                integer orderCount = 0;
	  			// Get the Master Account (HeadlightsDepot.com)
	            Account Acct; 
                for (Account MyAcct : Accts) {
                    if (MyAcct.Name == WebsiteControlName) Acct = MyAcct;
                }
	            String AcctID = Acct.Id;
	            // Get Orders
	            // NOTE: I'll define variables here for ALL fields returned from the
	            // Shipworks Generic Module php page, We may only use some of them to
	            // write to Salesforce but they will all be here just in case ...
	            url = base + '&action=getorders';
                if (OrderNumber != '') url = url + '&ordernumber=' + OrderNumber; else url = url + '&start=' + last.format('yyyy-MM-dd\'T\'hh:mm:ss\'Z\'');
                url = url + '&random=1234';
	            if (orderCount > 50) url = url + '&maxcount=' + (orderCount + 5);
	            req.setEndpoint(url);
                req.setTimeout(60 * 1000);
	            if (do_debug) debug(' -- CLASS -- url: ' + url);
				res = http.send(req);
	            //debug(' -- CLASS -- res: ' + res);
                if (do_debug) debug(' -- CLASS -- doc: ' + res.getBody());
				doc = res.getBodyDocument();
				Shipworks = doc.getRootElement();
	            // Get the new 'last' Download Date/Time from the response
	            Dom.XMLNode params = Shipworks.getChildElement('Parameters', null);
	            //last = DateTime.ValueOf(params.getChildElement('End', null).getText());
				// Get the MaxCount from the response
				integer MaxCount = integer.valueOf(params.getChildElement('MaxCount', null).getText());
				Dom.XMLNode Orders = Shipworks.getChildElement('Orders', null);
	            for(Dom.XMLNode Order : Orders.getChildElements()) {
                    if (OrderCount >= ctl.WebsiteOrderMax__c) continue;
                    SF_Order ThisOrder = new SF_Order();
                    ThisOrder.OrderLines = new List<ECS__Products_Purchased__c>();
                    ThisOrder.DebugEnable = ctl.WebsiteOrderDebug__c;
                    ThisOrder.SplitOrderlines = SplitOrderlines;
	                //Order Master Info
	                if (do_debug) Debug('Processing Order ' + Order.getChildElement('OrderNumber', null).getText());
	                String OrderNumber = Order.getChildElement('OrderNumber', null).getText();
					String OrderDate = Order.getChildElement('OrderDate', null).getText();
					String LastModified = Order.getChildElement('LastModified', null).getText();
					String ShippingMethod = Order.getChildElement('ShippingMethod', null).getText();
					String StatusCode = Order.getChildElement('StatusCode', null).getText();
	                String Comments = '';
	                Dom.XMLNode Notes = Order.getChildElement('Notes', null);
                    if (Notes != null) {
	                	for(Dom.XMLNode Note : Notes.getChildElements()) {
	                	    if (Comments != '') Comments = Comments + ', ';
	                	    Comments = Comments + Note.getText();
	                	}
                    }
	                // Shipping Address Info
	                String ShipFName = '';
	                String ShipLName = '';
	                String BillName = '';
	                String ShipName = '';
	                Dom.XMLNode ShipAddress = Order.getChildElement('ShippingAddress', null);
	                ShipName = ShipAddress.getChildElement('FullName', null).getText();
	                ShipFName = ShipAddress.getChildElement('FirstName', null).getText();
	                ShipLName = ShipAddress.getChildElement('LastName', null).getText();
	                String ShipStreet1 = ShipAddress.getChildElement('Street1', null).getText();
	                String ShipStreet2 = ShipAddress.getChildElement('Street2', null).getText();
	                String ShipStreet3 = ShipAddress.getChildElement('Street3', null).getText();
	                String ShipCity = ShipAddress.getChildElement('City', null).getText();
	                String ShipState = ShipAddress.getChildElement('State', null).getText();
	                String ShipZip = ShipAddress.getChildElement('PostalCode', null).getText();
	                String ShipCountry = ShipAddress.getChildElement('Country', null).getText();
	                String ShipPhone = ShipAddress.getChildElement('Phone', null).getText();
	                String ShipEmail = ShipAddress.getChildElement('Email', null).getText();
	                String ShipCompany = ShipAddress.getChildElement('Company', null).getText();
	                addEmail(ShipEmail); // Save Email to load Customers/Addresses
	                // Billing Address Info
	                String BillFName = '';
	                String BillLName = '';
	                Dom.XMLNode BillAddress = Order.getChildElement('BillingAddress', null);
	                BillName = BillAddress.getChildElement('FullName', null).getText();
	                BillFName = BillAddress.getChildElement('FirstName', null).getText();
	                BillLName = BillAddress.getChildElement('LastName', null).getText();
	                String BillCompany = BillAddress.getChildElement('Company', null).getText();
	                String BillStreet1 = BillAddress.getChildElement('Street1', null).getText();
	                String BillStreet2 = BillAddress.getChildElement('Street2', null).getText();
	                String BillStreet3 = BillAddress.getChildElement('Street3', null).getText();
	                String BillCity = BillAddress.getChildElement('City', null).getText();
	                String BillState = BillAddress.getChildElement('State', null).getText();
	                String BillZip = BillAddress.getChildElement('PostalCode', null).getText();
	                String BillCountry = BillAddress.getChildElement('Country', null).getText();
	                String BillPhone = BillAddress.getChildElement('Phone', null).getText();
	                String BillEmail = BillAddress.getChildElement('Email', null).getText();
                    addEmail(BillEmail); // Save Email to load customers/addresses
	                
	                // Payment info
	                Dom.XMLNode Payment = Order.getChildElement('Payment', null);
	                String PmtMethod = Payment.getChildElement('Method', null).getText();
	                Dom.XMLNode CreditCard = Payment.getChildElement('CreditCard', null);
	                String CC_Owner = CreditCard.getChildelement('Owner', null).getText();
					String CC_Type = CreditCard.getChildelement('Type', null).getText();
	                String CC_Num = CreditCard.getChildelement('Number', null).getText();
	                String CC_Exp = CreditCard.getChildelement('Expires', null).getText();
	                String TransactionID = Payment.getChildElement('TransactionID', null).getText();
	                // Order Items
	                List<List<String>> OrderItems = new List<List<String>>(); // list of lists
	                Integer ItemCount = 0; // total item count for order master
	                Dom.XMLNode Items = Order.getChildElement('Items', null);
	                for(Dom.XMLNode Item : Items.getChildElements()) {
	                    String ItemID = Item.getChildElement('ItemID', null).getText();
	                    String ProductID = Item.getChildElement('ProductID', null).getText();
	                    String ItemCode = Item.getChildElement('Code', null).getText();
	                    String ItemName = Item.getChildElement('Name', null).getText();
	                    String ItemQty = Item.getChildElement('Quantity', null).getText();
	                    String ItemPrice = Item.getChildElement('UnitPrice', null).getText();
                        if (ItemCode.right(5) == '-PREM') ItemCode = ItemCode.substringBefore('-PREM');
	                    List<String> MyItem = new List<String>{ItemID, ProductID, ItemCode, ItemName, ItemQty, ItemPrice};
	                    OrderItems.add(MyItem);
	                    ItemCount = ItemCount + integer.valueOf(ItemQty);
                        addSKU(ItemCode); // save the SKU to load products later
	                }
	                //Debug(' -- CLASS -- ' + ItemCount + ' Line Items for this order.');
	                Dom.XMLNode Totals = Order.getChildElement('Totals', null);
	                Decimal SubTotal = 0;
	                Decimal SalesTax = 0;
	                Decimal Shipping = 0;
	                String CouponName = '';
	                Decimal CouponAmt = 0;
	                for(Dom.XMLNode Total : Totals.getChildElements()) {
	                    String AttrName = Total.getAttributeValue('name', null);
	                    if (AttrName == 'subtotal') SubTotal = Decimal.valueOf(Total.getText());
	                    if (AttrName == 'salestax') SalesTax = Decimal.valueOf(Total.getText());
	                    if (AttrName == 'shipping') Shipping = Decimal.valueOf(Total.getText());
	                    if (Total.getAttributeValue('class', null) == 'coupon') { 
	                    	CouponName = Total.getAttributeValue('name', null);
	                        CouponAmt = Decimal.valueOf(Total.getText());
	                    }
	                }
	                Decimal OrderTotal = ((Subtotal + Shipping + SalesTax) - CouponAmt);
	                // OK, Now we will create the records but not save them yet ...
                    Contact Customer = new Contact(Account=Acct, Email=BillEmail, ECS__Customer_External_Id__c=BillEmail);
                    Customer.MailingStreet = BillStreet1;
                    Customer.MailingCity = BillCity;
                    Customer.MailingState = BillState;
                    Customer.MailingPostalCode = BillZip;
                    Customer.OtherStreet = ShipStreet1;
                    Customer.OtherCity = ShipCity;
                    Customer.OtherState = ShipState;
                    Customer.OtherPostalCode = ShipZip;
                  	Customer.Phone = BillPhone;
                    Customer.FirstName = BillFName;
                    Customer.LastName = BillLName;
                    ThisOrder.Customer = Customer;
                    // No CustID Yet (until we write everything)

                    ECS__Address__c Addr1 = new ECS__Address__c(ECS__Account__c = Acct.Id);
                    Addr1.Name = 'Billing Address for ' + OrderNumber;
                    Addr1.ECS__First_Name__c = BillFName;
                    Addr1.ECS__Last_Name__c = BillLName;
                    Addr1.ECS__Address_Line_1__c = BillStreet1;
                    Addr1.ECS__Address_Line_2__c = BillStreet2;
                    Addr1.ECS__Address_Line_3__c = BillStreet3;
                    Addr1.ECS__City__c = BillCity;
                    Addr1.ECS__State_Province_Region__c = BillState;
                    Addr1.ECS__Zip_Postal_Code__c = BillZip;
                    Addr1.ECS__Phone_Number__c = BillPhone;
                    Addr1.ECS__Email_Address__c = BillEmail;
                    Addr1.ECS__External_Address_ID__c = 'BillAddr for ' + OrderNumber;
                    Addr1.ECS__Is_Billing_Address__c = true;
                    // still needs 'Addr1.ECS__Customer__c = CustID'
                    ThisOrder.BillAddress = Addr1;
                    

                    ECS__Address__c Addr2 = new ECS__Address__c(ECS__Account__c = Acct.Id);
                    Addr2.Name = 'Shipping Address for ' + OrderNumber;
                    Addr2.ECS__First_Name__c = ShipFName;
                    Addr2.ECS__Last_Name__c = ShipLName;
                    Addr2.ECS__Address_Line_1__c = ShipStreet1;
                    Addr2.ECS__Address_Line_2__c = ShipStreet2;
                    Addr2.ECS__Address_Line_3__c = ShipStreet3;
                    Addr2.ECS__City__c = ShipCity;
                    Addr2.ECS__State_Province_Region__c = ShipState;
                    Addr2.ECS__Zip_Postal_Code__c = ShipZip;
                    Addr2.ECS__Phone_Number__c  = ShipPhone;
                    Addr2.ECS__Email_Address__c = ShipEmail;
                    Addr2.ECS__External_Address_ID__c = 'ShipAddr for ' + OrderNumber;
                    Addr1.ECS__Is_Shipping_Address__c = true;
                    // still needs 'Addr2.ECS__Customer__c = CustID'
                    ThisOrder.ShipAddress = Addr2;
                    
                    /* */
	                //system.Debug(' -- CLASS -- Creating new Order Master Record');
	                ECS__eCommSource_Order__c NewOrder = new ECS__eCommSource_Order__c(Name = OrderNumber);
	                NewOrder.ECS__Account__c = Acct.Id;
                    
	                NewOrder.ECS__Converted_Discount_Amount__c = CouponAmt;
	                NewOrder.ECS__Converted_Order_Total__c = ((Subtotal + Shipping + SalesTax) - CouponAmt);
	                NewOrder.ECS__Converted_Shipping_Amount__c = Shipping;
	                NewOrder.ECS__Converted_Tax__c = SalesTax;
	                NewOrder.ECS__Coupon_Code__c = CouponName;
	                NewOrder.ECS__Customer_Email_Address__c = BillEmail;
	                NewOrder.Customer_Name__c = BillName;
	                NewOrder.ECS__Discount_Amount__c = CouponAmt;
	                NewOrder.ECS__Downloaded__c = false; // ******** DOWNLOADED FLAG ********
	                NewOrder.ECS__External_Order_ID__c = '90' + OrderNumber;
	                NewOrder.ECS__Order_Status__c = 'New';
	                NewOrder.ECS__Order_Time__c = DateTime.valueOf(OrderDate.replace('T',' ')); //DateTime.valueOf(OrderDate);
	                NewOrder.ECS__Origin__c = WebsiteControlName;
	                NewOrder.ECS__Order_Type__c = 'Web';
	                NewOrder.ECS__Phone__c = BillPhone;
	                NewOrder.ECS__Tax_Total__c = SalesTax;
	                NewOrder.ECS__Total_Order_Amount__c = ((Subtotal + Shipping + SalesTax) - CouponAmt);
                    NewOrder.ECS__Sale_Site__c = WebsiteControlName;
                    NewOrder.ECS__Payment_Transaction_ID__c = TransactionID;
                    ThisOrder.Order = NewOrder;

					for (List<String> OrderItem : OrderItems) {
						if (do_debug) system.debug(' -- CLASS -- Adding a New OrderItem ...');
						// ItemID, ProductID, ItemCode, ItemName, ItemQty, ItemPrice
						String ItemID = OrderItem[0];
						String ProdID = OrderItem[1];
						String SKU = OrderItem[2];
						String ItemName = OrderItem[3];
						Decimal Qty = Decimal.valueOf(OrderItem[4]);
						Decimal Price = Decimal.valueOf(OrderItem[5]);
						String ObjName = OrderNumber + '_' + SKU;
                        //Debug(' -- CLASS -- Processing Product for ' + SKU);
						ECS__Products_Purchased__c OrderLine = new ECS__Products_Purchased__c(Name=SKU);
                        OrderLine.ECS__Account__c = AcctID;
                        OrderLine.ECS__Contact__c = null; // will be set later
						OrderLine.ECS__Order__c = null; // will be set later
						OrderLine.ECS__Product__c = null; // will be set later
                        OrderLine.ECS__Product_Title__c = ItemName;
                        OrderLine.ECS__Purchase_Date__c = DateTime.valueOf(OrderDate.replace('T',' '));
						OrderLine.ECS__Converted_Purchase_Price__c = Price;
                        OrderLine.ECS__Purchase_Price__c = Price;
                        OrderLine.ECS__Quantity_Purchased__c = Qty;
                        //debug('OrderLine: ' + OrderLine);
                        ThisOrder.OrderLines.add(OrderLine);
					}	                

	                // Create a Shipping Detail record for the Order
	                //Debug(' -- CLASS -- Creating new Shipping Detail Record');
	                ECS__Shipping_Detail__c ShipDetail = new ECS__Shipping_Detail__c(Name=OrderNumber);
	                ShipDetail.ECS__Account__c = AcctID;
	                //ShipDetail.ECS__Order__c = OrderID; // to be set later
	                //ShipDetail.ECS__Shipping_Address__c = Addr2.Id; // to be set later
	                ShipDetail.ECS__Carrier__c = ShipCarrier;
                    ShipDetail.ECS__Class__c = ShipClass;
                    ShipDetail.ECS__Origin__c = 'Schedule Fetch';
                    ShipDetail.ECS__Shipping_Carrier__c = ShipCarrier;
                    ShipDetail.ECS__Shipping_Class__c = ShipClass;
                     ThisOrder.Shipping = ShipDetail;

	                // Create a Shipping Detail record for the Order
	                //Debug(' -- CLASS -- Creating new Shipping Detail Record');
	                ECS__Payment_Detail__c PmtDetail = new ECS__Payment_Detail__c(Name=OrderNumber);
	                PmtDetail.ECS__Account__c = AcctID;
	                //PmtDetail.ECS__Order__c = OrderID; // to be set later
	                //PmtDetail.ECS__Address__c = Addr1.Id; // to be set later
	                //PmtDetail.ECS__Customer__c = CustID; // to be set later
	                PmtDetail.ECS__External_Payment_Id__c = OrderNumber;
                    PmtDetail.ECS__Status__c = 'Cleared';
                    PmtDetail.ECS__Origin__c = 'Schedule Fetch';
                    PmtDetail.ECS__payment_type__c = 'PayPal';
                    // TransactionID (Paypal TransactionID) is in the Order, not the Payment
                     ThisOrder.Payment = PmtDetail;
                    
                    SFOrders.add(ThisOrder);
                    
                    // Store the latest Order Date/Time in the WebsiteControl record
                    if (DateTime.valueOf(OrderDate.replace('T',' ')) > ctl.WebsiteOrderLastDownload__c) {
                        ctl.WebsiteOrderLastDownload__c = DateTime.valueOf(OrderDate.replace('T',' '));
                    }
                    
                    OrderCount = OrderCount + 1;
                    //Debug('Count=' + OrderCount + ', max=' + ctl.WebsiteOrderMax__c);
                    if (OrderCount >= ctl.WebsiteOrderMax__c) continue;
                    
	            } // end of for each Order
                //update ctl;
	        } // end of if Now >= Next Download Date/time
        	if (Limits.getQueries() > MaxQueries) { Debug('SOQL Query Limit Reached !');return; }
        } // end of for each WebsiteControl record
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		// OK, now we should have X number of SF_Order objects, each containing all of the records
		// that are required for each order, but the linking IDs are not set. We'll have to lookup
		// or insert the records, in order, get the IDs and assign them to their respective fields
		// before saving the next record types. So far.  WebsiteControl (ctls) and Account (Accts) 
        // are the only SOQL Queries that have been performed
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if (do_debug) debug(' -- CLASS -- ' + SFOrders.size() + ' SFOrders in the list to be created.');

        if (SFOrders.size() > 0) {
            // First: Load all products (by SKU) and Customers/Addresses (by Email)
            String ProductWhere = '';
            String AssocWhere = '';
            String ContactWhere = '';
            String AddressWhere = '';
            for (String SKU : SKUs) {
                if (AssocWhere == '') AssocWhere = ' WHERE ECS__Master_SKU__r.Name IN (';
                else AssocWhere = AssocWhere + ', ';
                AssocWhere = AssocWhere + '\'' + SKU + '\'';
            }
            if (AssocWhere != '') AssocWhere = AssocWhere + ')';
             for (String Email : Emails) {
                if (ContactWhere == '') ContactWhere = ' WHERE ';
                else ContactWhere = ContactWhere + ' OR ';
                ContactWhere = ContactWhere + 'Email = \'' + Email + '\' OR ECS__Secondary_Email_Address__c = \'' + Email + '\'';
                if (AddressWhere == '') AddressWhere = ' WHERE ';
                else AddressWhere = AddressWhere + ' OR ';
                AddressWhere = AddressWhere + 'ECS__Email_Address__c = \'' + Email + '\'';
            }
           
            List<Contact> Contacts = database.query('SELECT Id, Name, AccountID, Email, ECS__Customer_External_Id__c, Phone, Fax, firstName, lastName, MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry, OtherStreet, OtherCity, OtherState, OtherPostalCode, OtherCountry, ECS__Secondary_Email_Address__c FROM Contact ' + ContactWhere);
            if (do_debug) debug(' -- CLASS -- ' + Contacts.size() + ' Contacts Loaded.');

            List<ECS__Address__c> Addresses = database.query('SELECT Id, Name, ECS__Account__c, ECS__Address_Line_1__c, ECS__Address_Line_2__c, ECS__Address_Line_3__c, ECS__City__c, ECS__Company__c, ECS__Country__c, ECS__Customer__c, ECS__Email_Address__c, ECS__First_Name__c, ECS__Is_Billing_Address__c, ECS__Is_Shipping_Address__c, ECS__Last_Name__c, ECS__State_Province_Region__c, ECS__Zip_Postal_Code__c, ECS__Phone_Number__c FROM ECS__Address__c ' + AddressWhere);
            if (do_debug) debug(' -- CLASS -- ' + Contacts.size() + ' Addresses Loaded.');
	
            Assembly = database.query('SELECT Id, Name, ECS__External_Id__c, Master_Quantity__c, ECS__Master_SKU__c, ECS__Quantity_to_Build__c, ECS__Simple_Product__c, ECS__Simple_Product__r.Name, ECS__Cost__c  FROM ECS__Associated_Product__c ' + AssocWhere + ' ORDER BY ECS__Sort_Order__c, Name');
            if (do_debug) debug(' -- CLASS -- ' + Assembly.size() + ' Assemblies (Associated Product) Loaded.');
			// Add assembly component skus to SKUs array for product lookup
            for (ECS__Associated_Product__c Assy : Assembly) addSKU(Assy.ECS__Simple_Product__r.Name);

            for (String SKU : SKUs) {
                if (ProductWhere == '') ProductWhere = ' WHERE Name IN (';
                else ProductWhere = ProductWhere + ', ';
                ProductWhere = ProductWhere + '\'' + SKU + '\'';
            }
            if (ProductWhere != '') ProductWhere = ProductWhere + ')';
            
            Products = database.query('SELECT Id, Name, ECS__Available_for_Building__c, ECS__Distribution_Center_Quantity__c, ECS__Price__c, ECS__Cost__c, ECS__Title__c FROM ECS__Product__c ' + ProductWhere);
            if (do_debug) debug(' -- CLASS -- (424) ' + Products.size() + ' Products Loaded.');
            
            // Next: check to see if we have existing Contacts for each order, if not create them
            // and the addresses for them, if we do have an existing Contact for an order, then we
            // set the Customer in the order and check the Addr1/Addr2 against the contact's addresses
            // to see if we need to add another address for this contact to match the order's info.
            // NOTE: We will not upsert here, if there is no matching contact or address then we will
            // create a new one, we will not update an existing one (wherever/whoever we shipped remains)
            Contact[] ContactsToAdd;
            Address[] AddressesToAdd;
            for (SF_Order ThisOrder : SFOrders) {
                Contact Cust = ThisOrder.Customer;
                ECS__Address__c BillAddr = ThisOrder.BillAddress;
                ECS__Address__c ShipAddr = ThisOrder.ShipAddress;
                Boolean SplitOrderlines = ThisOrder.SplitOrderlines;
                do_debug = ThisOrder.DebugEnable;
                for (Contact Cont : Contacts) {
                    if (Cont.Email == Cust.Email || Cont.ECS__Secondary_Email_Address__c == Cust.Email) { 
                        if (do_debug) debug(' -- CLASS -- (442) Existing Contact (' + Cont.Name + ') for order ' + ThisOrder.Order.Name);
                        // OK, there's an existing contact by this email, update info and add to upsert list
                        for (ECS__Address__c Addr : Addresses) {
                            if (Addr.ECS__Customer__c == Cont.Id && Addr.ECS__Is_Billing_Address__c == true) { 
                                if (Addr.ECS__Address_Line_1__c.toLowerCase() == BillAddr.ECS__Address_Line_1__c.toLowerCase() && Addr.ECS__City__c.toLowerCase() == BillAddr.ECS__City__c.toLowerCase()) {
                                    BillAddr = Addr;
                                    ThisOrder.BillAddress = Addr;
                                    if (do_debug) debug(' -- CLASS -- (449) Existing Billing Address Found');
                                }
                            } 
                            if (Addr.ECS__Customer__c == Cont.Id && Addr.ECS__Is_Shipping_Address__c == true) {
                                if (Addr.ECS__Address_Line_1__c.toLowerCase() == ShipAddr.ECS__Address_Line_1__c.toLowerCase() && Addr.ECS__City__c.toLowerCase() == ShipAddr.ECS__City__c.toLowerCase()) {
       								ShipAddr = Addr;
                                    ThisOrder.ShipAddress = Addr;
                                    if (do_debug) debug(' -- CLASS -- (456) Existing Shipping Address Found');
                                }
                            } 
                        }
                       
                        if (ThisOrder.BillAddress.Id == null) {
                            UpsertAddresses.add(ThisOrder.BillAddress);
                            if (do_debug) debug(' -- CLASS -- (463) No Existing Billing Address, Adding it');
                        }
                        if (ThisOrder.ShipAddress.Id == null) {
                            UpsertAddresses.add(ThisOrder.ShipAddress);
                            if (do_debug) debug(' -- CLASS -- (467) No Existing Shipping Address, Adding it');
                        }
                        ThisOrder.Order.ECS__Customer__c = Cont.Id;
                        Cont.Phone = BillAddr.ECS__Phone_Number__c;
						Cont.FirstName = BillAddr.ECS__First_Name__c;
						Cont.LastName = BillAddr.ECS__Last_Name__c ;
                        Cont.MailingStreet = BillAddr.ECS__Address_Line_1__c;
                        if (BillAddr.ECS__Address_Line_2__c != null) Cont.MailingStreet = Cont.MailingStreet + ' ' + BillAddr.ECS__Address_Line_2__c;
                        if (BillAddr.ECS__Address_Line_3__c != null) Cont.MailingStreet = Cont.MailingStreet + ' ' + BillAddr.ECS__Address_Line_3__c;
                        if (do_debug) debug(' -- CLASS -- (476): ' + Cont.MailingStreet);
                        Cont.MailingCity = BillAddr.ECS__City__c;
                        Cont.MailingState = BillAddr.ECS__State_Province_Region__c;
                        Cont.MailingPostalCode = BillAddr.ECS__Zip_Postal_Code__c;
                        
                        UpsertContacts.add(Cont);
                        ThisOrder.Customer = Cont;
                    }
                }
                // if we never found an existing customer, add customer and addresses
                if (ThisOrder.Order.ECS__Customer__c == null) { 
                    if (do_debug) debug(' -- CLASS -- (487) No Customer found for order ' + ThisOrder.Order.Name + ', Adding Contact and Addresses');
                    UpsertContacts.add(ThisOrder.Customer);
                    UpsertAddresses.add(ThisOrder.BillAddress);
               		UpsertAddresses.add(ThisOrder.ShipAddress);
                }
                for (ECS__Products_Purchased__c OrderLine : ThisOrder.OrderLines) {
                    for (ECS__Product__c Product : Products) {
                        if (Product.Name == OrderLine.Name) OrderLine.ECS__Product__c = Product.Id;
                    }
                    if (OrderLine.ECS__Product__c == null) { // NO Matching Product
                        ECS__Product__c Product = new ECS__Product__c(Name=OrderLine.Name);
                        Product.ECS__External_Product_ID__c = OrderLine.Name;
                        Product.ECS__External_SKU__c = OrderLine.Name;
                        //Product.Notes__c = 'Created ' + DateTime.valueOf(OrderDate.replace('T',' ')) + ' By ScheduleFetchWebsiteOrders because Product Not Found';
                        Product.ECS__Price__c = OrderLine.ECS__Purchase_Price__c;
                        Product.ECS__Title__c = OrderLine.ECS__Product_Title__c;
                        ProductsToAdd.add(Product);
                    }
                } // end of for each OrderLine
                    
            } // end of for each order
            // Now perform all of the database updates: Add new products
            if (do_debug) debug(' -- CLASS -- (509) ' + ProductsToAdd.size() + ' Inventory Products to add ...');
            List<Database.upsertResult> PResults = Database.upsert(ProductsToAdd,false);
            ProductsToAdd = merge_results(ProductsToAdd,PResults);
            merge_lists(ProductsToAdd, Products);
            
            // Add/Update Contacts
            if (do_debug) debug(' -- CLASS -- (516) ' + UpsertContacts.size() + ' Contacts to Upsert ...');
            List<Database.upsertResult> CResults = Database.upsert(UpsertContacts,false);
            UpsertContacts = merge_results(UpsertContacts, CResults);
            report_results(CResults);
            merge_lists(UpsertContacts, Contacts); // now 'Contacts' contains all records
            if (do_debug) debug(' -- CLASS -- (520): ' + Contacts.size() + ' Contacts in the list.');
            
            // Post any newly created Contact IDs to their Addresses
            for (ECS__Address__c MyAddr : UpsertAddresses) {
                String FName = MyAddr.ECS__First_Name__c;
                String LName = MyAddr.ECS__Last_Name__c;
                String Addr = MyAddr.ECS__Address_Line_1__c; // + ' ' + MyAddr.ECS__Address_Line_2__c + ' ' + MyAddr.ECS__Address_Line_3__c;
                Addr = Addr.trim();
                if (MyAddr.ECS__Customer__c == null) { // This Address is not assigned to a customer yet
                	if (do_debug) Debug(' -- CLASS -- (529): UpsertAddress (' + FName + '/' + LName + '/' + Addr + ') Customer is null, matching contacts ...');
                    for (Contact Cust : Contacts) {
                    	if (do_debug) debug(' -- CLASS -- (531) Cust: (' + Cust.FirstName + '/' + Cust.LastName + '/' + Cust.MailingStreet + '/' + Cust.OtherStreet + ')');
                        if (Cust.FirstName == FName && Cust.LastName == LName && (Cust.MailingStreet == Addr || Cust.OtherStreet == Addr)) {
                            MyAddr.ECS__Customer__c = Cust.Id;
                            if (do_debug) debug(' -- CLASS -- (534) Assigning new address to ' + FName + ' ' + LName + ' (Mailing)');
                        }
                    }
                }
            }
            // Add/Update Addresses
            if (do_debug) debug(' -- CLASS -- (540) ' + UpsertAddresses.size() + ' Addresses to Upsert ...');
            List<Database.upsertResult> AResults = Database.upsert(UpsertAddresses, ECS__Address__c.Fields.ECS__External_Address_ID__c,false);
            UpsertAddresses = merge_results(UpsertAddresses, AResults);
            report_results(AResults);
            merge_lists(UpsertAddresses, Addresses); // now 'Addresses' contains all records
            if (do_debug) debug(' -- CLASS -- (545) Addresses now has ' + Addresses.size() + ' Addresses.');
            // Now update the SF_Order objects with any new Contact, Address and Product info
            for (SF_Order SF_Order : SFOrders) {
                if (SF_Order.Customer.Id == null || SF_Order.Order.ECS__Customer__c == null) {
                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (549) Customer.Id or Order.Customer are null');
                    String FName = SF_Order.Customer.FirstName;
                    String LName = SF_Order.Customer.LastName;
                    String Addr = SF_Order.Customer.MailingStreet;
                    for (Contact Cust : Contacts) {
                        if (Cust.FirstName == FName && Cust.LastName == LName && Cust.MailingStreet == Addr) {
                            SF_Order.Customer.Id = Cust.Id;
                            SF_Order.Order.ECS__Customer__c = Cust.Id;
                            if (SF_Order.DebugEnable) debug(' -- CLASS -- (557) Assigning Contact (' + Cust.FirstName + ' ' + Cust.LastName + ' to Order ' + SF_Order.Order.Name);
                        }
                    }
                } else {
                    if (do_debug) debug(' -- CLASS -- (561) Customer.Id and Order.Customer are non-null');
                }
                if (SF_Order.BillAddress.Id == null) {
                    String FName = SF_Order.BillAddress.ECS__First_Name__c;
                    String LName = SF_Order.BillAddress.ECS__Last_Name__c;
                    String Addr = SF_Order.BillAddress.ECS__Address_Line_1__c;
                    for (ECS__Address__c Addr2 : Addresses) {
                        if (Addr2.ECS__First_Name__c == FName && Addr2.ECS__Last_Name__c == LName && Addr2.ECS__Address_Line_1__c == Addr) {
                            SF_Order.BillAddress.Id = Addr2.Id;
                            if (SF_Order.DebugEnable) debug(' -- CLASS -- (570) Assigning Address ' + Addr2.Name + ' to BillAddress obj.');
                        }
                    }
                }
                if (SF_Order.ShipAddress.Id == null) {
                    String FName = SF_Order.ShipAddress.ECS__First_Name__c;
                    String LName = SF_Order.ShipAddress.ECS__Last_Name__c;
                    String Addr = SF_Order.ShipAddress.ECS__Address_Line_1__c;
                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (578) ShipAddress.Id is null for (' + FName + '/' + LName + '/' + Addr + ') - checking Addresses ...');
                    for (ECS__Address__c Addr2 : Addresses) {
                    	if (SF_Order.DebugEnable) debug(' -- CLASS -- (580)  Addr2: (' + Addr2.ECS__First_Name__c + '/' + Addr2.ECS__Last_Name__c + '/' + Addr2.ECS__Address_Line_1__c + ')');
                        if (Addr2.ECS__First_Name__c == FName && Addr2.ECS__Last_Name__c == LName && Addr2.ECS__Address_Line_1__c == Addr) {
                            SF_Order.ShipAddress.Id = Addr2.Id;
                            if (SF_Order.DebugEnable) debug(' -- CLASS -- (583) Assigning Address ' + Addr2.Name + ' to ShipAddress obj.');
                        }
                    }
                }
                for (ECS__Products_Purchased__c Line : SF_Order.OrderLines) {
                    if (Line.ECS__Product__c == null) {
                    	if (SF_Order.DebugEnable) debug(' -- CLASS -- (589) Purchased Product ' + Line.Name + ' has no product yet.');
                        for (ECS__Product__c Product : Products) {
                            if (Product.Name == Line.Name) {
                                Line.ECS__Product__c = Product.Id;
                                if (SF_Order.DebugEnable) debug(' -- CLASS -- (593 Assigning ' + Product.Name + '\'s id to ProdPurch ' + Line.Name);
                            }
                        }
                    }
                }
                // Add Order to UpsertOrders
                UpsertOrders.Add(SF_Order.Order);
            } // end of for each SF_Order
            
            // Add/Update Orders
            if (do_debug) Debug(' -- CLASS -- (603) ' + UpsertOrders.size() + ' UpsertOrders to send.');
            List<Database.upsertResult> OResults = Database.upsert(UpsertOrders, ECS__eCommSource_Order__c.Fields.ECS__External_Order_ID__c,false);
            UpsertOrders = merge_results(UpsertOrders, OResults);
            boolean OrdersInserted = report_results(OResults);
            
            // Add the Order ID to the OrderLines
            for (ECS__eCommSource_Order__c Order : UpsertOrders) {
                //if (do_debug) debug(' -- CLASS -- (610) setting Order Id from UpsertOrder ' + Order.Name);
                for (SF_Order SF_Order : SFOrders) {
                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (612) SF_Order:' + SF_Order.Order.Name + ', Cust:' + SF_Order.Order.ECS__Customer__c);
                    if (SF_Order.Order.Name == Order.Name && SF_Order.Order.ECS__Customer__c == Order.ECS__Customer__c) {
                        SF_Order.Order.Id = Order.Id;
                        for (ECS__Products_Purchased__c PurchProd : SF_Order.OrderLines) {
                            if (SF_Order.DebugEnable) debug(' -- CLASS -- (616) SF_Order.OrderLine (PurchProd) ' + PurchProd.Name);
                            if (PurchProd.ECS__Order__c == null) PurchProd.ECS__Order__c = Order.Id;
                            if (PurchProd.ECS__Contact__c == null) PurchProd.ECS__Contact__c = SF_Order.Customer.Id;
                            if (PurchProd.ECS__External_Purchased_Product_ID__c == null) PurchProd.ECS__External_Purchased_Product_ID__c = Order.ECS__External_Order_ID__c + '-' + PurchProd.Name;
                            UpsertPurchProd.Add(PurchProd);
                            ECS__Product__c product = getProductBySKU(PurchProd.Name);
                            if (product != null) { // we found our product in the list
                                if (SF_Order.DebugEnable) Debug(' -- CLASS -- (623 product ' + PurchProd.Name + ' found: DistCtrQty=' + product.ECS__Distribution_Center_Quantity__c + ', AvailForBldg=' + product.ECS__Available_for_Building__c);
                                // If we have no DistibutionCenterQty but we can build them, put Assembly items in OrderLines
                                if (product.ECS__Distribution_Center_Quantity__c == 0 && product.ECS__Available_for_Building__c > 0 && SF_Order.SplitOrderlines == true) {
                                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (626) No DistCtrQty but product AvailForBldg');
                                    Decimal AssyCost = 0;
                                    for (ECS__Associated_Product__c Assy : Assembly) {
                                        if (Assy.ECS__Master_SKU__c == product.Id) {
                                            AssyCost = AssyCost + Assy.ECS__Cost__c;
                                        }
                                    }
                                    Decimal Percent = PurchProd.ECS__Purchase_Price__c / AssyCost;
                                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (634) Assy: $' + PurchProd.ECS__Purchase_Price__c + ', Tot: $' + AssyCost + ', Pct: $' + Percent);
                                    for (ECS__Associated_Product__c Assy : Assembly) {
                                        if (Assy.ECS__Master_SKU__c == product.Id) {
                                            ECS__Product__c AssyPart = getProductById(Assy.ECS__Simple_Product__c);
                                            ECS__eCommSource_Order_Line__c OLine = new ECS__eCommSource_Order_Line__c(Name=AssyPart.Name);
                                            OLine.ECS__Customer__c = Order.ECS__Customer__c;
                                            OLine.ECS__External_Order_Line_ID__c = 'HD.com-' + Order.ECS__External_Order_ID__c + '-' + AssyPart.Name;
                                            OLine.ECS__Order__c = Order.Id;
                                            OLine.ECS__Product__c = AssyPart.Id;
                                            OLine.ECS__Product_Title__c = AssyPart.ECS__Title__c;
                                            OLine.ECS__Quantity__c = PurchProd.ECS__Quantity_Purchased__c * Assy.ECS__Quantity_to_Build__c;
                                            Oline.ECS__Unit_Price__c = Assy.ECS__Cost__c * Percent;
                                            UpsertOrderLines.Add(OLine);
                                            if (SF_Order.DebugEnable) debug(' -- CLASS -- (647) Added OrderLine: $' + Oline.ECS__Unit_Price__c);
                                        }
                                    }
                                } else { // no, we have this item on the shelf so put the item sold on the orderline
                                    ECS__eCommSource_Order_Line__c OLine = new ECS__eCommSource_Order_Line__c(Name=product.Name);
                                    OLine.ECS__Customer__c = Order.ECS__Customer__c;
                                    OLine.ECS__External_Order_Line_ID__c = 'HD.com-' + Order.ECS__External_Order_ID__c + '-' + product.Name;
                                    OLine.ECS__Order__c = Order.Id;
                                    OLine.ECS__Product__c = product.Id;
                                    OLine.ECS__Product_Title__c = product.ECS__Title__c;
                                    OLine.ECS__Quantity__c = PurchProd.ECS__Quantity_Purchased__c;
                                    Oline.ECS__Unit_Price__c = PurchProd.ECS__Purchase_Price__c;
                                    UpsertOrderLines.Add(OLine);
                                    if (SF_Order.DebugEnable) debug(' -- CLASS -- (660) Added OrderLine: $' + Oline.ECS__Unit_Price__c);
                                } // end of if/else we have this product on the shelf
                            } else {
                                if (SF_Order.DebugEnable) debug(' -- CLASS -- (663) Product ' + PurchProd.Name + ' Not Found (null)');
                            } // end of if/else (product != null) (we found our product in the list)
                        } // end of for each PurchProd in SF_Order.OrderLines
                        
                        
                        SF_Order.Shipping.ECS__Customer__c = Order.ECS__Customer__c;
                        SF_Order.Shipping.ECS__Order__c = Order.Id;
                        SF_Order.Shipping.ECS__External_Id__c = Order.Id;
						UpsertShipDetail.add(SF_Order.Shipping);          
						
						SF_Order.Payment.ECS__Customer__c = Order.ECS__Customer__c; 
						SF_Order.Payment.ECS__Order__c = Order.Id; 
						SF_Order.Payment.ECS__External_Payment_Id__c = Order.Id;       
						UpsertPmtDetail.add(SF_Order.Payment);   
                     } // end of if this SF_Order matches the UpsertOrder
                } // end of for each SF_Order (looking to match UpsertOrder)
            } // end of for each UpsertOrder (now have Order IDs for inserted orders)
            if (OrdersInserted) {
            	// Add/Update Products Purchased
            	if (do_debug) Debug(' -- CLASS -- (682) ' + UpsertPurchProd.size() + ' UpsertPurchProd recds to send.');
            	List<Database.upsertResult> PPResults = Database.upsert(UpsertPurchProd, ECS__Products_Purchased__c.Fields.ECS__External_Purchased_Product_ID__c,false);
            	report_results(PPResults);
            	//Debug('Products Purchased Results: ' + PPResults);
            	UpsertPurchProd = merge_results(UpsertPurchProd, PPResults);
            
            	// Add/Update OrderLines
            	if (do_debug) Debug(' -- CLASS -- (689) ' + UpsertOrderLines.size() + ' UpsertOrderLine recds to send.');
            	List<Database.upsertResult> OLResults = Database.upsert(UpsertOrderLines, ECS__eCommSource_Order_Line__c.Fields.ECS__External_Order_Line_ID__c,false);
                  report_results(OLResults);
            	UpsertOrderLines = merge_results(UpsertOrderLines, OLResults);

                // Add/Update ShippingDetails
            	if (do_debug) Debug(' -- CLASS -- (695) ' + UpsertShipDetail.size() + ' UpsertShipDetail recds to send.');
            	List<Database.upsertResult> SDResults = Database.upsert(UpsertShipDetail, ECS__Shipping_Detail__c.Fields.ECS__External_Id__c,false);
                report_results(SDResults);
            	UpsertShipDetail = merge_results(UpsertShipDetail, SDResults);
                
                // Add/Update PaymentDetails
            	if (do_debug) Debug(' -- CLASS -- (701) ' + UpsertShipDetail.size() + ' UpsertShipDetail recds to send.');
            	List<Database.upsertResult> PDResults = Database.upsert(UpsertPmtDetail, ECS__Payment_Detail__c.Fields.ECS__External_Payment_Id__c,false);
                report_results(PDResults);
            	UpsertPmtDetail = merge_results(UpsertPmtDetail, PDResults);
                
            	// Update the WebsiteControl record(s) with the latest Order DateTimes
            	update ctls;
            } else {
            	debug('Skipped OrderLines and PurchasedProducts (Orders Failed)');
            }
            
        } // end of if (SFOrders.size() > 0)
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        if (do_debug) debug(' -- CLASS -- PROCESS FINISHED: ' + Limits.getQueries() + ' total SOQL queries');
        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    } // end of execute() function
    
    // ===========================================================================================
    public void Debug(String Message) {
     	system.Debug(message);
        Messages.add(message);
    }
    // ===========================================================================================
    public void add2count(String Message) {
        QueryCount = QueryCount + 1;
        //Messages.add(' -- CLASS -- QueryCount=' + QueryCount + ' (' + Limits.getQueries() + ') : ' + message);
    }
    // ===========================================================================================
    public void addEmail(String Email) {
        boolean Found = false;
        for (String Str : Emails) if (Str == Email) Found = true;
        if (Found == false) Emails.add(Email);
    }
    // ===========================================================================================
    public void addSKU(String SKU) {
        boolean Found = false;
        for (String Str : SKUs) if (Str == SKU) Found = true;
        if (Found == false) SKUs.add(SKU);
        //debug(' -- addSKU -- SKU=' + SKU + ', SKUs=' + SKUs);
    }
    // ===========================================================================================
    public ECS__Product__c getProductBySKU(String SKU) {
        //debug(' -- getProductBySKU(' + SKU + '): ' + Products.size() + ' Products.');
        ECS__Product__c MyProduct = null;
        for (ECS__Product__c product : Products) {
            if (product.Name == SKU) {
                //debug(' -- getProductBySKU(' + SKU + '): returning' + Product.Name);
                MyProduct = product;
            }
        }
        //debug(' -- getProductBySKU(' + SKU + '): returning null (not found)');
        return MyProduct;
    }
    // ===========================================================================================
    public ECS__Product__c getProductByID(String ID) {
        //debug(' -- getProductByID(' + ID + '): ' + Products.size() + ' Products.');
        ECS__Product__c MyProduct = null;
        for (ECS__Product__c product : Products) {
            if (product.ID == ID) {
                //debug(' -- getProductByID(' + ID + '): returning' + Product.Name);
                MyProduct = product;
            }
        }
        //debug(' -- getProductByID(' + ID + '): returning null (not found)');
        return MyProduct;
    }
    // ===========================================================================================
    //public List<ECS__Associated_Product__c> getAssemblies(String ProductID) {
    //    List<ECS__Associated_Product__c> Assys = new List<ECS__Associated_Product__c>();
    //    for (ECS__Associated_Product__c assy : Assembly) {
    //        if (Assy.ECS__Master_SKU__c == ProductID) Assys.add(Assy);
    //    }
    //    return Assys;
    //}
    // ===========================================================================================
    public List<sObject> merge_results(List<sObject> Source, List<Database.upsertResult> Results) {
        if (Source.size() == Results.size()) {
	        Integer i = 0;
	        for (Database.upsertResult Result : Results) {
	            if (Result.isCreated() == true || Result.isSuccess() == true || Source[i].Id == null) Source[i].Id = Result.getId();
	            i = i + 1;
	        }
        }
        return Source;
    }
    // ===========================================================================================
    public List<sObject> merge_lists(List<sObject> Source, List<sObject> Target) {
        for (sObject src : Source) {
            boolean Found = false;
            for (sObject tgt : Target) {
                if (tgt.Id == src.Id) Found = true;
            }
            if (Found == false) Target.add(src);
        }
        return Target;
    }
    // ===========================================================================================
    public boolean report_results(List<Database.upsertResult> Results) {
        integer recds = 0;
        integer inserts = 0;
        integer updates = 0;
        integer success = 0;
        integer failed = 0;
        for (Database.upsertResult Result : Results) {
            Recds++;
            if (Result.isSuccess()) {
                success++;
                if (Result.isCreated()) inserts++;
                else updates++;
            } else {
                failed++;
            }
        }
        if (do_debug) debug('' + recds + ' Records: ' + success + ' Success (' + inserts + ' inserted, ' + updates + ' updates), ' + failed + ' failed.');
        if (failed > 0) {
            debug('' + Results);
            return false;
        }
        return true;
    }
    // ===========================================================================================
} // end of class