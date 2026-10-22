# HTTP request

The action **HTTP request** sends one request to an internet address or to an address of the local network, and stores the answer in a variable or in a file. Only `http` and `https` addresses are allowed.

## Settings

### URL

The address of the resource, for example `http://someorg.org/api`.

### Post data

- **Do not upload any data**: the request has no body. The method is GET.
- **Use following post data**: the text of the field **Post data** is sent. The method is POST.
- **Use file as source (upload)**: the content of the file **File path** is sent as it is, without any text conversion. The method is POST.

Check **URI encode post data** if the text must be encoded for a web form (spaces and special characters become `%20` and so on).

**Charset**: the text is sent in UTF-8 by default. Choose **Define codepage** to send it in another codepage, for example `1252`. **Define charset** takes a name that AutoHotkey knows, such as `UTF-8`, `UTF-16` or `CP1252`; the charset names of v1 (such as `iso-8859-1`) are not all known (MIGRATION M-0143).

### Request headers

One header per line, written as `Name: value`, for example `X-Token: 42`. A header without a colon ends the element with an exception. A header that the element sets itself (for example User-Agent) is replaced by the line of this field.

### Response data

- **Write response data to a variable**: the text of the answer is stored in the variable **Output variable**. The text is decoded with the charset that the server sends.
- **Write response data to file (download)**: the bytes of the answer are written to **File path**. Use this for binary data. The file is replaced.

### Response headers

The name of the variable that receives the response headers, one per line, as the server sent them.

### Content type

Automatic sends no Content-Type header. Custom sends the text of the field. Only with post data.

### Content length

Automatic lets Windows calculate the length of the body. Custom sends the text of the field as the Content-Length header. Only with post data.

### Content MD5

- **Do not use**: no Content-MD5 header.
- **Automatic**: the MD5 digest of the body, in the form that the header needs (base64).
- **Custom**: the text of the field as the Content-MD5 header.

### Method

Automatic is POST with post data and GET without it. Custom takes one of GET, HEAD, POST, PUT, DELETE, OPTIONS or TRACE.

### User agent

Automatic is the user agent of Windows. Custom sends the text of the field as the User-Agent header.

### Flags

The field is kept so that flows of v1 load. It has no effect in AutoHotFlow 2: the WinINet flags of v1 have no equivalent in the library that the element uses (MIGRATION M-0142).

### Proxy

- **No proxy**: the request goes directly to the server.
- **Automatic**: the proxy of the system is used, as Windows configures it.
- **Custom**: the proxy in the form `host:port`, for example `proxy.example.com:8080`.

**Bypass proxy**: with a custom proxy, the addresses of the list are reached directly (for example `*.example.com`). It has no effect with the other choices (MIGRATION M-0144).

## Status and errors

The status of the answer is not an error: a 404 or a 500 answer is stored like any other answer, as in v1. An exception ends the element when the request cannot be sent (no connection, a name that cannot be resolved), when the URL is not `http` or `https`, when a header has no colon, or when a file cannot be read or written. A request that takes longer than 10 minutes ends with the exception "worker timeout" (MIGRATION M-0141).

The variable **A_BytesDownloaded** (thread variable) gets the number of bytes of the answer.

## Examples

Send a form and store the answer.

| Parameter | Value |
| --- | --- |
| URL | `http://someorg.org/form` |
| Post data | Use following post data |
| Post data text | `name=Paul&lang=de` |
| URI encode post data | off |
| Content type | Custom: `application/x-www-form-urlencoded` |
| Output variable | `answer` |
