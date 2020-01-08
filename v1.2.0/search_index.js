var documenterSearchIndex = {"docs": [

{
    "location": "#",
    "page": "Home",
    "title": "Home",
    "category": "page",
    "text": ""
},

{
    "location": "#ZMQ.jl-1",
    "page": "Home",
    "title": "ZMQ.jl",
    "category": "section",
    "text": "A Julia interface to ZeroMQ.ZMQ.jl is a Julia interface to ZeroMQ, The Intelligent Transport Layer."
},

{
    "location": "#Package-Features-1",
    "page": "Home",
    "title": "Package Features",
    "category": "section",
    "text": "Access ZeroMQ sockets from JuliaThe Guide provides a tutorial explaining how to get started using ZMQ.jl.Some examples of packages using Documenter can be found on the Examples page.See the Reference for the complete list of documented functions and types."
},

{
    "location": "man/guide/#",
    "page": "Guide",
    "title": "Guide",
    "category": "page",
    "text": ""
},

{
    "location": "man/guide/#Guide-1",
    "page": "Guide",
    "title": "Guide",
    "category": "section",
    "text": ""
},

{
    "location": "man/guide/#Usage-1",
    "page": "Guide",
    "title": "Usage",
    "category": "section",
    "text": "using ZMQ\n\ns1=Socket(REP)\ns2=Socket(REQ)\n\nbind(s1, \"tcp://*:5555\")\nconnect(s2, \"tcp://localhost:5555\")\n\nsend(s2, \"test request\")\nmsg = recv(s1, String)\nsend(s1, \"test response\")\nclose(s1)\nclose(s2)The send(socket, x) and recv(socket, SomeType) functions make an extra copy of the data when converting between ZMQ and Julia.   Alternatively, for large data sets (e.g. very large arrays or long strings), it can be preferable to share data, with send(socket, Message(x)) and msg = recv(Message), where the msg::Message object acts like an array of bytes; this involves some overhead so it may not be optimal for short messages.(Help in writing more detailed documentation would be welcome!)"
},

{
    "location": "man/examples/#",
    "page": "Examples",
    "title": "Examples",
    "category": "page",
    "text": ""
},

{
    "location": "man/examples/#Examples-1",
    "page": "Examples",
    "title": "Examples",
    "category": "section",
    "text": ""
},

{
    "location": "reference/#",
    "page": "Reference",
    "title": "Reference",
    "category": "page",
    "text": ""
},

{
    "location": "reference/#Reference-1",
    "page": "Reference",
    "title": "Reference",
    "category": "section",
    "text": ""
},

]}
