from http.server import HTTPServer, SimpleHTTPRequestHandler

server = HTTPServer(('0.0.0.0', 8080), SimpleHTTPRequestHandler)
print("Server running on port 8080")
server.serve_forever()
