package server

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"time"

	"github.com/nats-io/nats.go"
	"github.com/simpleiot/simpleiot/client"
	"github.com/simpleiot/simpleiot/data"
)

var testServerOptions = Options{
	StoreFile:    "test.sqlite",
	NatsPort:     4990,
	HTTPPort:     "8990",
	NatsHTTPPort: 8991,
	NatsWSPort:   8992,
	NatsServer:   "nats://localhost:4990",
}

var testServerOptions2 = Options{
	StoreFile:    "test2.sqlite",
	NatsPort:     4980,
	HTTPPort:     "8980",
	NatsHTTPPort: 8981,
	NatsWSPort:   8982,
	NatsServer:   "nats://localhost:4980",
}

// TestServer starts a test server and returns a function to stop it
func TestServer(args ...string) (*nats.Conn, data.NodeEdge, func(), error) {
	exec.Command("sh", "-c", "rm test.sqlite*").Run()

	opts := testServerOptions

	if len(args) > 0 {
		opts = testServerOptions2
	}

	s, nc, err := NewServer(opts)

	if err != nil {
		return nil, data.NodeEdge{}, nil, fmt.Errorf("Error starting siot server: %v", err)
	}

	clients, err := client.DefaultClients(nc)
	s.AddClient(clients)

	stopped := make(chan struct{})

	go func() {
		err := s.Start()
		if err != nil {
			log.Println("Test Server start returned: ", err)
		}
		close(stopped)
	}()

	stop := func() {
		s.Stop(nil)
		<-stopped
		exec.Command("sh", "-c", "rm test.sqlite*").Run()
	}

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*5)
	err = s.WaitStart(ctx)
	cancel()
	if err != nil {
		return nil, data.NodeEdge{}, stop, fmt.Errorf("Error waiting for test server to start: %v", err)
	}

	nodes, err := client.GetNodes(nc, "root", "all", "", false)

	if err != nil {
		return nil, data.NodeEdge{}, stop, fmt.Errorf("Get root nodes error: %v", err)
	}

	if len(nodes) < 1 {
		return nil, data.NodeEdge{}, stop, fmt.Errorf("Did not get a root node")
	}

	return nc, nodes[0], stop, nil
}
