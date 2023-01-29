class Clients {
    constructor() {
        this.clientList = [];
        this.saveClient = this.saveClient.bind(this);
    }
    saveClient(client) {
        this.clientList.push(client);
    }
}



const clients = new Clients();

var wss = new (require('ws')).Server({
  server: require('http').createServer(function (request, response) {
    response.end()
  }).listen(process.env.PORT || 5000)
});

wss.on('connection', function connection(ws) {
    console.log('new connection');
    // Add the client to the list
    clients.saveClient(ws);
  
    ws.on('message', function incoming(data) {
      console.log('received something');
      // Send the data to the other client
 
      console.log(data);
      // arr = [...data];

      // console.log(arr.length);
      // console.log(arr);
      // console.log(arr[0]);
      // newArr = [];
      // for (var i = 0; i < arr.length; i+=4) {
      //   newArr.push(arr[i])
      // }


      // WIDTH = 256
      // HEIGHT = 192
      // console.log(' ');
      clients.clientList.forEach((client) => {
        if (client !== ws) {
          client.send(data);
        }
      });
    });
  
    ws.on('close', function close() {
      console.log('lost connection');
      // Remove the client from the list
      clients.clientList = clients.clientList.filter((client) => client !== ws);
    });
  });
  


console.log('started server at ws://localhost:8765');