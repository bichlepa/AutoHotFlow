# HTTP Request

The action **HTTP Request** is capable of making HTTP Request to an internet resource in the internet or in local network.

## Settings

### URL

The URL of the internet resource you wish to access.

### Post data

Data that will be uploaded. Either a specified text or a file may be uploaded.

Check **URI encode post data** if the text should be URI encoded. Commonly, POST data from a web form must be URI encoded.

**Charset**: Change the charset or the codepage if the server does not accept UTF-8 charset.

### Request headers

AHF automatically sets up some request headers. If additional headers are wished, they can be specified here.

Check **URI encode request headers** if the text should be URI encoded.

### Response data

The response data may be written to a variable or to a text file.

If the download will contain binary data, please, use a file.

If the response data are not needed, it can be left blank.

### Response headers

Specify a variable which will contain the response headers.

If the response headers are not needed, it can be left blank.

### Content type

If some data is uploaded, AHF will automatically add the Content-Type header. It can be overridden by specifying an other content type. Default values for this header are:

- `application/octet-stream` when uploading from a file and the file's extension is neither "txt" nor "xml"
- `text/xml` when the string "&lt;?xml" appears near the beginning of the data
- `application/x-www-form-urlencoded` in all other casesa

### Content length

If some data is uploaded, AHF will automatically add the Content-Length header. It can be overridden by specifying an other content length.

If AHF can't determine the content length automatically (e.g: you are uploading non-text data), you must provide the "Content-Length" header with the total number of bytes you wish to upload. Note for UTF-8 charset: if you are uploading text, the number of bytes in text is twice the length of the text.

### Content MD5

If some data is uploaded, AHF will automatically add the Content-MD5 header. It can be overridden by specifying an other content MD5.

### Method

If some data is uploaded, AHF will use POST method, otherwise GET method will be used. It can be overridden by specifying an other method.

### User agent

AHF will add the "User-Agent" header to every request. By default, your script name, AHK version, and OS are used. If this is unacceptable to you, provide your own "User-Agent" header.

### Flags

Some flags can be added using a + sign or removed using a - sign. Internet flags can be found here. Security flags can be found here.

*Examples:*

- `+INTERNET_FLAG_NO_COOKIES` *Tells WinINet to NOT automatically handle cookies (by default, WinINet uses Internet Explorer's cookie pool). This is required if you want your flow to manage cookies with this action. If your request headers contain any "Cookie" headers, this option is applied automatically.*
- `+INTERNET_FLAG_NO_AUTO_REDIRECT` *Does not automatically handle redirection in HttpSendRequest.*
- `+SECURITY_FLAG_IGNORE_UNKNOWN_CA` *Ignores unknown certificate authority problems.*

### Proxy

AutoHotFlow may use a proxy to access an internet resource. If Automatic is selected, Internet Exlporer's proxy configuration will be used. If your Internet Explorer is not configured to use a proxy, this option has no effect. If Custom is selected, AHF will use the specified proxy.

*Examples:*

- `http://www.exampleproxy.com:1234`

Bypass proxy: Tells AHF NOT to use a proxy to access a specified website. This has no effect unless AHF has been told to use a proxy via the Custom option.

## Remarks

Many thanks to VxE for providing the outstanding HTTPRequest library.
