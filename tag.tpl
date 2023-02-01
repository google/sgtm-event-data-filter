___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Spiify Tag",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "Filters text in event data based on configuration and re-sends the filtered event data to all tags with a new \"filtered\" parameter to be picked up by tags with a trigger looking for this parameter.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "CHECKBOX",
    "name": "loggingEnabled",
    "checkboxText": "Enable Logging",
    "simpleValueType": true
  },
  {
    "type": "LABEL",
    "name": "eventDataLabel",
    "displayName": "\u003cbr\u003e\u003cstrong\u003eNotice:\u003c/strong\u003e\nThis tag adds an \u003cstrong\u003eEvent Data\u003c/strong\u003e property of \u003cstrong\u003efiltered\u003c/strong\u003e with a value of \u003cstrong\u003etrue\u003c/strong\u003e after it\u0027s filtered the data before passing it to other tags again. This property-value combination should be used as a trigger for other tags that are meant to only process filtered data or (used as an exclusion) to avoid it.\u003cbr\u003e\u003cbr\u003e"
  },
  {
    "type": "GROUP",
    "name": "filterConfiguration",
    "displayName": "Filter Configuration",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "SIMPLE_TABLE",
        "name": "filters",
        "displayName": "",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "Target",
            "name": "target",
            "type": "SELECT",
            "selectItems": [
              {
                "value": "eventParameters",
                "displayValue": "Event Parameters"
              },
              {
                "value": "userProperties",
                "displayValue": "User Properties"
              },
              {
                "value": "pageLocation",
                "displayValue": "Page Location"
              },
              {
                "value": "pageReferrer",
                "displayValue": "Page Referrer"
              }
            ],
            "macrosInSelect": false,
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          },
          {
            "defaultValue": "",
            "displayName": "Info Type",
            "name": "infoType",
            "type": "TEXT",
            "valueValidators": [
              {
                "type": "REGEX",
                "args": [
                  "^[a-zA-Z0-9_]+$"
                ],
                "errorMessage": "Info types can only contain alphanumeric characters and underscores."
              }
            ],
            "valueHint": ""
          },
          {
            "defaultValue": ".*",
            "displayName": "Key Pattern",
            "name": "keyPattern",
            "type": "TEXT",
            "valueValidators": [
              {
                "type": "NON_EMPTY",
                "enablingConditions": [
                  {
                    "paramName": "target",
                    "paramValue": "eventParameters",
                    "type": "EQUALS"
                  }
                ]
              },
              {
                "type": "NON_EMPTY",
                "enablingConditions": [
                  {
                    "paramName": "target",
                    "paramValue": "userProperties",
                    "type": "EQUALS"
                  }
                ]
              }
            ]
          },
          {
            "defaultValue": "",
            "displayName": "Value Pattern",
            "name": "valuePattern",
            "type": "TEXT",
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          },
          {
            "defaultValue": "redact",
            "displayName": "Method",
            "name": "method",
            "type": "SELECT",
            "selectItems": [
              {
                "value": "redact",
                "displayValue": "Redact"
              },
              {
                "value": "remove",
                "displayValue": "Remove"
              }
            ],
            "macrosInSelect": false,
            "valueValidators": [
              {
                "type": "NON_EMPTY"
              }
            ]
          }
        ]
      },
      {
        "type": "SIMPLE_TABLE",
        "name": "ignoreParameters",
        "displayName": "Ignore (Only Applies to Top Level Event Data Parameters)",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "",
            "name": "key",
            "type": "TEXT"
          }
        ]
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// capture start-time very first to ensure accurate performance checks.
const timestamp = require('getTimestampMillis');
const startTime = timestamp();

// request and response specific methods.
const request = {
  isAnalytics: require('isRequestMpv2'),
  eventData: require('getAllEventData')
};

const response = {
  success: data.gtmOnSuccess,
  failure: data.gtmOnFailure
};

// utility classes/methods.
const runContainer = require('runContainer');
const logToConsole = require('logToConsole');
const encodeUriComponent = require('encodeUriComponent');
const parseUrl = require('parseUrl');
const type = require('getType');

// globals
let cache = {};

if (request.isAnalytics()) {
  const eventData = request.eventData();
  // filter only once (prevents looping).
  if (!eventData.filtered) {
    const filteredEventData = filter(eventData);
    sendToTags(filteredEventData, response.success);
    return;
  }
}

response.success();

/**
 * Redact the text from the event data based on filter configuration
 * and return the resulting event data object.
 *
 * @returns {Object}
 */
function filter(eventData) {
  log('Filtering event data...');

  for (const key in eventData) {
    let value = eventData[key];

    // skip any system keys or keys ignored by the configuration.
    if (ignoredParameter(key)) {
      continue;
    }

    for (const filter of data.filters) {
      switch (key) {
        case 'x-ga-mp2-user_properties':
          if (filter.target === 'userProperties') {
            value = userPropertyFilter(filter, value);
          }
          break;
        case 'page_location':
          if (filter.target === 'pageLocation') {
            value = urlFilter(filter, value);
          }
          break;
        case 'page_referrer':
          if (filter.target === 'pageReferrer') {
            value = urlFilter(filter, value);
          }
          break;
        default:
          if (filter.target === 'eventParameters' && key.indexOf('x-') !== 0) {
            value = eventParameterFilter(filter, key, value);
          }
          break;
      }
    }

    eventData[key] = value;
  }

  eventData.filtered = true;
  log('Complete.');
  return eventData;
}

/**
 * This is called once the function it's provided to has completed
 * (including any async processing that happens).
 *
 * @callback CompletionCallback
 */

/**
 * Send filtered event data to all tags again by re-running the container.
 *
 * @param {Object} filteredEventData
 * @param {CompletionCallback} callback
 */
function sendToTags(filteredEventData, callback) {
  log('Sending filtered event data to tags set to process filtered data...');
  runContainer(filteredEventData, () => {
    log('Complete.');
    callback();
  });
}

/**
 * Parse the ignored parameters from the filter configuration into an array
 * and compare the provided key against that array of ignored keys.
 *
 * @param {string} key
 *
 * @returns {boolean}
 */
function ignoredParameter(key) {
  if (type(cache.ignoreParameters) === 'undefined') {
    const systemParameters = [
      'client_id',
      'event_name',
      'ga_session_id',
      'ga_session_number',
      'language',
      'screen_resolution',
      'engagement_time_msec'
    ];

    const ignoreParameters = data.ignoreParameters ? data.ignoreParameters.map(item => item.key) : [];
    cache.ignoreParameters = unique(ignoreParameters.concat(systemParameters));
  }

  return cache.ignoreParameters.indexOf(key) !== -1;
}

/**
 * Redact text from value if the key and value match the provided filter.
 *
 * @param {Object} filter
 * @param {string} key
 * @param {mixed} value
 *
 * @returns {mixed}
 */
function eventParameterFilter(filter, key, value) {
  const text = filterMatch(key, value, filter);
  if (text) {
    value = replace(text, filteredVariant(filter), value);
  }

  return value;
}

/**
 * Redact text from user properties if the key and value of any of the properties match the provided filter.
 *
 * @param {Object} filter
 * @param {Object} userProperties
 *
 * @returns {Object}
 */
function userPropertyFilter(filter, userProperties) {
  for (const key in userProperties) {
    const value = userProperties[key];
    const text = filterMatch(key, value, filter);
    if (text) {
      userProperties[key] = replace(text, filteredVariant(filter), value);
    }
  }

  return userProperties;
}

/**
 * Redact text from url if the key and value of any of the parameters within it match the provided filter.
 *
 * @param {Object} filter
 * @param {string} url
 *
 * @returns {string}
 */
function urlFilter(filter, url) {
  const urlParameters = parseUrl(url).searchParams;
  let filteredUrl = url;

  for (const key in urlParameters) {
    const value = urlParameters[key];
    const text = filterMatch(key, value, filter);
    if (text) {
      const encodedKey = encodeUriComponent(key);
      const encodedText = encodeUriComponent(text);
      const possiblePairings = [
        encodedKey + '=' + encodedText,
        encodedKey + '=' + text,
        key + '=' + encodedText,
        key + '=' + text
      ];
      const encodedKeyAndFilteredText = encodedKey + '=' + filteredVariant(filter);
      filteredUrl = replace(possiblePairings, encodedKeyAndFilteredText, filteredUrl);
    }
  }

  // catch multiple instances of text matching the same filter by running the filter again when necessary.
  return filteredUrl !== url ? urlFilter(filter, filteredUrl) : url;
}

/**
 * Check the key and value against the filter and if they match the filter then return the value match.
 *
 * @param {string} key
 * @param {mixed} value
 * @param {Object} filter
 *
 * @returns {string}
 */
function filterMatch(key, value, filter) {
  const keyMatches = key.toLowerCase().match(filter.keyPattern);
  if (keyMatches) {
    const valueMatches = value.toString().toLowerCase().match(filter.valuePattern);
    if (valueMatches && value !== filteredVariant(filter)) {
      return valueMatches[0];
    }
  }
}

/**
 * Return the filtered variant.
 * This will vary depending on the filter method specified in the configuration.
 *
 * @param {Object} filter
 *
 * @returns {string}
 */
function filteredVariant(filter) {
  switch (filter.method) {
    case 'redact':
      return '[REDACTED ' + filter.infoType + ']';
    case 'remove':
      return '';
  }
}

/**
 * Log all parameters to the console for troubleshooting purposes.
 * Only logs if logging is enabled via the client configuration.
 * Prepends the client name to all log entries.
 *
 * @param {...mixed}
 */
function log() {
  if (data.loggingEnabled) {
    const starter = '[Spiify Tag]' + ' [' + (timestamp() - startTime) + 'ms]';
    // no spread operator is available in sandboxed JS.
    switch (arguments.length) {
      case 1:
        logToConsole(starter, arguments[0]);
        break;
      case 2:
        logToConsole(starter, arguments[0], arguments[1]);
        break;
      case 3:
        logToConsole(starter, arguments[0], arguments[1], arguments[2]);
        break;
      case 4:
        logToConsole(starter, arguments[0], arguments[1], arguments[2], arguments[3]);
        break;
      case 5:
        logToConsole(starter, arguments[0], arguments[1], arguments[2], arguments[3], arguments[4]);
        break;
    }
  }
}

/**
 * Returns the unique items in the array provided.
 *
 * @param {string[]} array The array from which to filter out duplicates.
 *
 * @returns {string[]}
 */
function unique(array) {
  return array.filter((item, index, list) => list.indexOf(item) === index);
}

/**
 * Allows replacing in a case-insensitive way while maintaining the case of the haystack.
 * Accepts either a single needle to replace or an array of them.
 *
 * @param {string|string[]} needle
 * @param {string} replacement
 * @param {string} haystack
 *
 * @returns {string}
 */
function replace(needle, replacement, haystack) {
  // if an array is provided for the needle loop over each needle and replace each one after the other.
  if (type(needle) === 'array') {
    for (const n of needle) {
      haystack = replace(n, replacement, haystack);
    }
    return haystack;
  }

  const lowerCaseNeedle = needle.toLowerCase();
  const start = haystack.toString().toLowerCase().indexOf(lowerCaseNeedle);
  if (start === -1) {
    return haystack;
  }
  const end = start + lowerCaseNeedle.length;
  const exactNeedle = haystack.slice(start, end);
  return haystack.toString().replace(exactNeedle, replacement);
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "all"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "run_container",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Already Filtered is Ignored
  code: |-
    mock('getAllEventData', function() {
      return {filtered: true};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasNotCalled();
- name: Non-GA4 Request is Ignored
  code: |-
    mock('getAllEventData', function() {
      return {filtered: false};
    });

    mock('isRequestMpv2', function() {
      return false;
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasNotCalled();
- name: Event Parameter With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {email: 'test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      email: '[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Event Parameter (Method - Remove) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'remove'
      }
    ];

    mock('getAllEventData', function() {
      return {email: 'test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      email: '',
      filtered: true
    });
- name: Event Parameter (Case Specific Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {EMail: 'test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      EMail: '[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Event Parameter (Multi-Match) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(e[-]?mail)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {email: 'test@example.com', 'e-mail': 'test254@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      email: '[REDACTED EMAIL_ADDRESS]',
      'e-mail': '[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: User Property With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "userProperties",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {'x-ga-mp2-user_properties': {email: 'test@example.com'}};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      'x-ga-mp2-user_properties': {email: '[REDACTED EMAIL_ADDRESS]'},
      filtered: true
    });
- name: User Property (Method - Remove) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "userProperties",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'remove'
      }
    ];

    mock('getAllEventData', function() {
      return {'x-ga-mp2-user_properties': {email: 'test@example.com'}};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      'x-ga-mp2-user_properties': {email: ''},
      filtered: true
    });
- name: User Property (Case Specific Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "userProperties",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {'x-ga-mp2-user_properties': {EMail: 'test@example.com'}};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      'x-ga-mp2-user_properties': {EMail: '[REDACTED EMAIL_ADDRESS]'},
      filtered: true
    });
- name: User Property (Multi-Match) With Text Filtered
  code: "mockData.filters = [\n  {\n    target: \"userProperties\",\n    infoType:\
    \ \"EMAIL_ADDRESS\",\n    keyPattern: \"^(e[-]?mail)$\",\n    valuePattern: \"\
    .{1,}\\\\@.{1,}\\\\.[a-z]{2,10}\".replace('\\\\\\\\', '\\\\'),\n    method: 'redact'\n\
    \  }\n];\n\nmock('getAllEventData', function() {\n  return {'x-ga-mp2-user_properties':\
    \ {email: 'test@example.com', 'e-mail': 'test254@example.com'}};\n});\n\n// Call\
    \ runCode to run the template's code.\nrunCode(mockData);\n\nassertApi('runContainer').wasCalled();\n\
    assertThat(eventData).isEqualTo({\n  'x-ga-mp2-user_properties': {\n    email:\
    \ '[REDACTED EMAIL_ADDRESS]', \n    'e-mail': '[REDACTED EMAIL_ADDRESS]'\n  },\n\
    \  filtered: true\n});"
- name: Page Location (Any Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '.*',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Specific Encoded Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(e%mail)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Specific Non-Encoded Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(email)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&email=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&email=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Specific Key - Multi-Match) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(e[-]?mail)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&email=test%40example.com&E-Mail=test245%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&email=[REDACTED EMAIL_ADDRESS]&E-Mail=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Method - Remove) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '.*',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'remove'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=',
      filtered: true
    });
- name: Page Location (Avoid Infinitely Replacing Redacted Statement)
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "FIRST_NAME",
        keyPattern: '^(fname)$',
        valuePattern: ".*",
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&fname=john'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&fname=[REDACTED FIRST_NAME]',
      filtered: true
    });
- name: Page Location (Non-Encoded Key) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(e%mail)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&e%mail=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Non-Encoded Value) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(e%mail)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Location (Non-Encoded Key & Value) With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '^(e%mail)$',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_location: 'https://example.com/profile?id=test%40example.com&e%mail=test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_location: 'https://example.com/profile?id=test%40example.com&e%25mail=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Page Referrer With Text Filtered
  code: |-
    mockData.filters = [
      {
        target: "pageReferrer",
        infoType: "EMAIL_ADDRESS",
        keyPattern: '.*',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {page_referrer: 'https://example.com/profile?id=test%40example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      page_referrer: 'https://example.com/profile?id=[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Ignored Parameters are not Filtered
  code: |
    mockData.filters = [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "(email)",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mockData.ignoreParameters = [{"key":"support-email"}];

    mock('getAllEventData', function() {
      return {'support-email': 'support@example.com', 'email': 'test@example.com'};
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      'support-email': 'support@example.com',
      'email': '[REDACTED EMAIL_ADDRESS]',
      filtered: true
    });
- name: Filters Apply Only to Their Parameter Set
  code: |-
    mockData.filters = [
      {
        target: "pageLocation",
        infoType: "PL_EMAIL_ADDRESS",
        keyPattern: '.*',
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      },
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "(email)",
        valuePattern: ".{1,}(\\@|\\%40).{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ];

    mock('getAllEventData', function() {
      return {
        email: 'test@example.com',
        page_location: 'https://example.com/profile?email=test%40example.com'
      };
    });

    // Call runCode to run the template's code.
    runCode(mockData);

    assertApi('runContainer').wasCalled();
    assertThat(eventData).isEqualTo({
      email: '[REDACTED EMAIL_ADDRESS]',
      page_location: 'https://example.com/profile?email=[REDACTED PL_EMAIL_ADDRESS]',
      filtered: true
    });
setup: |-
  const JSON = require('JSON');
  const promise = require('Promise');
  const defer = require('callLater');

  const requestPath = '/g/collect/';

  const mockData = {
    loggingEnabled: false,
    filters: [
      {
        target: "eventParameters",
        infoType: "EMAIL_ADDRESS",
        keyPattern: "^(email)$",
        valuePattern: ".{1,}\\@.{1,}\\.[a-z]{2,10}".replace('\\\\', '\\'),
        method: 'redact'
      }
    ],
    ignoreParameters: []
  };

  let eventData;
  mock('runContainer', function(rcEventData, callback) {
    eventData = rcEventData;
    callback();
  });

  mock('getRequestPath', function() {
    return requestPath;
  });

  mock('isRequestMpv2', function() {
    return true;
  });


___NOTES___

Created on 12/16/2022, 5:57:19 PM


