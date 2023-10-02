chrome.webRequest.onBeforeSendHeaders.addListener(
  function (request) {
    var newUAs = [
      "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)",
    ];
    var newUA = newUAs[0];
    var gotUA = false;
    for (var i = 0; i < request.requestHeaders.length; ++i) {
      if (request.requestHeaders[i].name == "User-Agent") {
        request.requestHeaders[i].value = newUA;
        var gotUA = true;
        break;
      }
    }
    if (!gotUA) {
      request.requestHeaders.push({
        name: "User-Agent",
        value: newUA,
      });
    }
    return {
      requestHeaders: request.requestHeaders,
    };
  },
  {
    urls: [
      "https://www.haaretz.co.il/*",
      "https://www.haaretz.com/*",
      "https://www.themarker.com/*",
      "https://youtu.be/dQw4w9WgXcQ?t=31",
      "https://blog.nrwl.io/",
      "https://medium.com/"
    ],
  },
  ["blocking", "extraHeaders", "requestHeaders"]
);