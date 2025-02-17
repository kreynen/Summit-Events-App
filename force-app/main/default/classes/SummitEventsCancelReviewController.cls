// Copyright (c) 2020, Salesforce.org. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause.
// License can be found found in the LICENSE file in this repository.
// Created by Thaddaeus Dahlberg on  5/1/2018.

public with sharing class SummitEventsCancelReviewController {
    public SummitEventsShared SEShared = new SummitEventsShared();
    public Summit_Events_Registration__c eventRegistration { get; set; }
    public SummitEventsShared.SummitEventsInfo eventInformation { get; set; }
    public List<Summit_Events_Appointments__c> appointments { get; set; }
    public String templateSelected { get; set; }
    public Boolean eventOver { get; set; }
    public Boolean eventNotFound { get; set; }
    public String formattedNavDate { get; set; }
    public String eventParameter { get; set; }

    public SummitEventsCancelReviewController() {
        eventParameter = ApexPages.currentPage().getParameters().get('eventInfo');
        eventNotFound = true;
        eventOver = false;

        if (!String.isBlank(eventParameter)) {
            String decryptedParameter = SEShared.decryptString(eventParameter, false);
            if (String.isNotBlank(decryptedParameter)) {
                try {
                    eventInformation = (SummitEventsShared.SummitEventsInfo) JSON.deserialize(decryptedParameter, SummitEventsShared.SummitEventsInfo.class);
                } catch (Exception e) {
                    System.debug(e.getMessage());
                }

                if (String.isNotBlank(eventInformation.registrationId)) {
                    eventRegistration = [
                            SELECT Id, Status__c, Name, Event__r.Name, Event_Instance__c, Event__r.Event_Name__c, Event__r.Event_description__c,
                                    Event__r.Event_Footer__c, Event__r.Event_Cancel_Review_Title__c, Event_Name__c, Event_Instance__r.Instance_Title__c,
                                    Event__r.Event_Cancel_Review_Description__c, Event__r.Event_Cancelled_Notification_Text__c,
                                    Event__r.Template__c, Event__r.Event_Home_Link_Title__c, Event__r.Event_Home_Link_URL__c,
                                    Event_Instance__r.Instance_Start_Date__c, Event_Instance__r.Instance_Start_Time__c,
                                    Event_Instance__r.Instance_End_Date__c, Event_Instance__r.Instance_End_Time__c, Event_Instance__r.Instance_Time_Zone__c,
                                    Event__r.Tracking_Cancel_Registration__c
                            FROM Summit_Events_Registration__c
                            WHERE Id = :eventInformation.registrationId
                            WITH SECURITY_ENFORCED
                    ];


                    if (eventRegistration != null) {

                        templateSelected = SEShared.getTemplate(eventRegistration.Event__r.Template__c);

                        SummitEventsShared SEShared = new SummitEventsShared();

                        appointments = [
                                SELECT Id, Appointment_Title__c, Appointment_Category__c, Appointment_Type__c
                                FROM Summit_Events_Appointments__c
                                WHERE Event_Registration__c = :eventParameter
                                WITH SECURITY_ENFORCED
                        ];

                        List<Summit_Events_Instance__c> eventInstance = [
                                SELECT Id, Event__r.Event_Name__c, Instance_Title__c,
                                        Instance_Start_Date__c, Instance_End_Date__c, Instance_Start_Time__c, Instance_End_Time__c, Instance_Time_Zone__c
                                FROM Summit_Events_Instance__c W
                                WHERE Id = :eventRegistration.Event_Instance__c
                                WITH SECURITY_ENFORCED
                        ];

                        if (SEShared.convertDateToDatetime(eventRegistration.Event_Instance__r.Instance_End_Date__c, null, '') < SEShared.adjustForTimeZone(Datetime.now(), eventRegistration.Event_Instance__r.Instance_Time_Zone__c)) {
                            eventOver = true;
                        }

                        if (eventInstance.size() > 0) {
                            formattedNavDate = SEShared.navBreadcrumbBuilder(eventInstance[0]);
                        }
                        eventNotFound = false;
                    }
                }
            }
        }
    }

    public PageReference cancelRegistration() {
        doCRUD regCrud = new doCRUD();
        if (eventRegistration != null) {
            eventRegistration.Status__c = 'Cancelled';
            eventRegistration = regCrud.updateRegistration(eventRegistration);
        }
        PageReference pg = Page.SummitEventsCancelReview;
        pg.getParameters().put('eventInfo', eventParameter);
        pg.setRedirect(true);
        return pg;
    }

    /**
     * Summit Events is a multi-step, guest user, registration solution so CRUD work needs to be done on records where guest record ownership is lost between steps.
     * The security aspects of guest record updating is achieved by:
     * - Using an encrypted cookie on the client browser to keep track of registration id, event id, instance id, and audience
     * - Dividing each controller class into a "with sharing" logic area and a sub "without sharing" CRUD area for purposeful CRUD
     * - When the encrypted cookie is not available as in the cancel registration link an encrypted string is provided through the URL to not expose the SF ID related to the record
     **/

    private without sharing class doCRUD {

        public Summit_Events_Registration__c updateRegistration(Summit_Events_Registration__c newEvtReg) {
            try {
                update newEvtReg;
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }
            return newEvtReg;
        }

    }

}