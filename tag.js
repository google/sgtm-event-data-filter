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