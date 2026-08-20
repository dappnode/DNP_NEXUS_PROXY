package main

import (
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"
)

const healthURL = "http://127.0.0.1:3301/healthz"

func main() {
	client := &http.Client{
		Timeout: 3 * time.Second,
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return errors.New("redirects are not allowed")
		},
	}
	request, err := http.NewRequest(http.MethodGet, healthURL, nil)
	if err != nil {
		fail(err)
	}
	response, err := client.Do(request)
	if err != nil {
		fail(err)
	}
	defer response.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 4<<10))
	if response.StatusCode != http.StatusOK {
		fail(fmt.Errorf("health endpoint returned HTTP %d", response.StatusCode))
	}
}

func fail(err error) {
	_, _ = fmt.Fprintf(os.Stderr, "nexus-proxy health check failed: %v\n", err)
	os.Exit(1)
}
