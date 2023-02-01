# Spiify Documentation
Copyright 2023 Google LLC.

> **Important:** This is not an officially supported Google product. This solution, including any related sample code or data, is made available on an "as is," "as available," and "with all faults" basis, solely for illustrative purposes, and without warranty or representation of any kind. This solution is experimental, unsupported and provided solely for your convenience. Your use of it is subject to your agreements with Google, as applicable, and may constitute a beta feature as defined under those agreements. To the extent that you make any data available to Google in connection with your use of the solution, you represent and warrant that you have all necessary and appropriate rights, consents and permissions to permit Google to use and process that data. By using any portion of this solution, you acknowledge, assume and accept all risks, known and unknown, associated with its usage and any processing of data by Google, including with respect to your deployment of any portion of this solution in your systems, or usage in connection with your business, if at all. With respect to the entrustment of personal information to Google, you will verify that the established system is sufficient by checking Google's privacy policy and other public information, and you agree that no further information will be provided by Google.

> **Note:** This tag template is intended to be used in situations where you have unwanted text that may come through in event parameters, user properties, or page location or referrer urls in analytics requests made to sGTM that needs to be filtered/redacted before that event data is sent to Google Analytics 4. Any other use of this template is untested.

> **Warning:** There is no guarantee of the unwanted text being completely filtered/redacted and it is the responsibility of anyone using this template to ensure that the tag is working as expected. This will require monitoring and adjustments be made to the tag configuration on an ongoing basis along with continued audits of the Google Analytics data to ensure the tag is filtering properly and if not that the necessary action is taken to remove/redact the unwanted text from Google Analytics.

## Description
This tag template takes every analytics request (/g/collect) that comes in, pulls the event data from it, redacts specific text based on regex patterns specified in the tag configuration, and sends the (now filtered) event data back to the container to be processed by any other tag. The filtered event data will contain a **filtered** parameter set to **true**. This allows triggering the GA4 tag using this filtered parameter ultimately giving the ability to filter this unwanted text out without losing the built-in behaviors from the Google Analytics 4 client and tag.


## Installation and Configuration
### Download the Repository and Unzip/Extract
1. [Download the repository](https://github.com/google/sgtm-event-data-filter/archive/refs/heads/main.zip) and extract the contents.
2. The **tag.tpl** file is the .tpl file you'll need for the next step.

### Import the Server-side Google Tag Manager Tag Template
1. Once looking at the server-side container within Tag Manager select **Templates** in the left menu.
2. On the templates page next to **Tag Templates** select **New**.
3. From here select the **three vertical dots menu** next to save and select **Import**.
4. Select the **Spiify Tag template** (tag.tpl file as mentioned above) and once loaded select **Save** in the upper right corner.

### Create & Configure the Tag That Will Use This Template
1. Once looking at the server-side container within Tag Manager select **Tags** in the left menu.
2. On the tags page next to **Tags** select **New**.
3. Change the name in the top left to something more identifiable for the purpose such as **Spiify Tag**.
4. Select anywhere in the **Tag Configuration** box.
5. In the menu that appears select **Spiify Tag**.
6. In the configuration check **Enable Logging** to have aspects of the process logged to the console in preview mode (generally for troubleshooting), create the **Filter Configuration** entries for anything you want to redact (the name will show instead of the actual value - [REDACTED PHONE_NUMBER] for example), add any parameters under Ignore you wish to have Spiify ignore and not accidentally filter (only applies to top level event data parameters).

### Add Custom Variables
> Will be used in conjunction with the triggers created following the guide below in server-side tag configurations to gate the requests that those tags processes.

1. Once looking at the server-side container within Tag Manager select **Variables** in the left menu.
2. On the variables page next to **User-Defined Variables** select **New**.
3. Change the name in the top left to something more identifiable for the purpose such as **Filtered by Spiify**.
4. Select anywhere in the **Variable Configuration** box.
5. In the menu that appears select **Event Data** under **Utilities**.
6. In the box that appears under type **filtered**.
7. Select **Save** at the top right.

### Add Custom Triggers
> Will be used in conjunction with the variables created following the guide above in server-side tag configurations to gate the requests that those tags processes.

1. Once looking at the server-side container within Tag Manager select **Triggers** in the left menu.
2. On the variables page next to **Triggers** select **New**.
3. Change the name in the top left to something more identifiable for the purpose such as **Events Filtered by Spiify**.
4. Select anywhere in the **Trigger Configuration** box.
5. In the menu that appears select **Custom**.
6. Below this select that this trigger fires on **Some Events** then in the first dropdown select our custom variable we just created (**Filtered by Spiify**), in the second dropdown select **equals** and in the third type **true**.
7. Select **Save** at the top right.
8. Create an unfiltered trigger. Follow steps 1-7, but in step 3 use **Events Not Filtered by Spiify** as the name and in step 6 select **not equals** instead of equals in the dropdown.

### Add Triggers to Tags
> Add your **Filtered** trigger as a firing trigger or add your **Not Filtered** trigger as an exception to any tag you wish to only run if the request has first been filtered.

1. Once looking at the server-side container within Tag Manager select **Tags** in the left menu.
2. Select the **name hyperlink** to edit the tag configuration.
3. On the configuration window that opens select anywhere in the **Triggering** box and then select the + icon on the right.
Or select **Add Exception** if you have existing firing triggers and want to use the **Not Filtered** trigger as an exception instead.
4. In the menu that opens select our newly created Trigger - **Events Filtered by Spiify** (or **Events Not Filtered by Spiify** if you are adding an exception).
5. Select **Save** at the top right.


## Troubleshooting / Seeing the Proof
### Getting Started
1. Once looking at the server-side container within Tag Manager select Preview at the top right.
2. Once looking at the client-side container within Tag Manager select Preview at the top right.
3. In the client-side container preview window that opens once you connect interact with the page in some way then go to the server-side container preview.

### Redactions in Action
Select one of the events that came in such as **page_view** and select the **Event Data** tab.
> **Note:** There will be two events for each request (one filtered and the other unfiltered/untouched) i.e. only one of the events (the second in the set) will have redacted data.

### Ensuring Tags are Firing Correctly
Select one of the events that came in such as **page_view** and select the **Variables** tab. You should see **Filtered by Spiify**. If the value of it is **true** then the Google Analytics 4 tag **should have fired**.

This can be confirmed by selecting the **Tags** tab; there the tags configured to run for requests filtered by Spiify should be listed.

The opposite should also be true. If **Filtered by Spiify** has a value of **undefined** then the Google Analytics 4 tag **should not have fired**. The other tags that are configured to process unfiltered data should have fired in the prior event at the same time the Spiify tag fired.

This can be confirmed by selecting the **Tags** tab; there the tags configured to run for requests not filtered by Spiify should be listed.

### The Tag at Work
The first event for every request (with the lower number of the two next to it) should show the Spiify tag having fired. Click the incoming and outgoing requests on the Request tab to get additional details on each. To see logs (if you have **logging enabled** via the tag configurations) you'll see more details under the **Console** tab as it filters the event data and passes it along. This also shows time elapsed since the Spiify tag started processing the request so you can see the latency this tag adds to each request (this will vary based on your setup).


## Regular Expression Filter Examples

> **Warning:** These are not defaults! These are provided only as examples and **do not guarantee that all the unwanted text of these info types will be filtered**. Depending on the environment they are used in they **could result in loss of data (accidentally filtering text that is needed unexpectedly) or could fail to filter the unwanted text entirely if not tested and adjusted properly**. Do not use these as-is.

<br>

### **NAME**

**Key Pattern**<br>
`^(f|fst|frst|first|l|lst|last|s|sur)?[_\-]?(n|nm|name)?$`

**Value Pattern**<br>
`([\w\,\.\'\-]+\s?){1,6}`
________________________________________________________
### **PHONE_NUMBER**

**Key Pattern**<br>
`^(t|tl|tel|tele|m|mob|mobile)?[_\-]?(p|ph|phn|phone)?[_\-]?(n|nm|num|numb|number)?$`

**Value Pattern**<br>
`([+]?[0-9]{0,2}[\-\s]*(\(?[0-9]{3}\)?)[\-\s]*[0-9]{3}[\-\s]*[0-9]{4}|(\(?[0-9]{3}\)?)?[\-\s]*[0-9]{3}[\-\s]*[0-9]{4})`
________________________________________________________
### **EMAIL_ADDRESS**

**Key Pattern**<br>
`^(e|em)[_\-]?(mail|ml)?[_\-]?(a|ad|adr|addr|address)?$`

**Value Pattern**<br>
`.{1,}\@.{1,}\.[a-z]{2,10}`
________________________________________________________
### **PASSWORD**

**Key Pattern**<br>
`^(pw|pwd|pswd|pwrd|pass|passwd|passwrd|paswrd|paswd|password)$`

**Value Pattern**<br>
`.{5,}`
________________________________________________________
### **ZIPCODE**

**Key Pattern**<br>
`^(p|post|postal|z|zp|zip)?[_\-]?(c|cd|code)?$`

**Value Pattern**<br>
`[0-9]{5}([\-][0-9]{4})?`