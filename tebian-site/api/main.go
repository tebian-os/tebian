package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"
)

type Counts struct {
	PC    int `json:"pc"`
	Pi    int `json:"pi"`
	Cloud int `json:"cloud"`
}

var (
	counts Counts
	mu     sync.Mutex
)

func getPort() string {
	if port := os.Getenv("PORT"); port != "" {
		return ":" + port
	}
	return ":3001"
}

func getDataDir() string {
	if dir := os.Getenv("DATA_DIR"); dir != "" {
		return dir
	}
	return "/data"
}

func getCountsFile() string {
	return getDataDir() + "/downloads.json"
}

func loadCounts() {
	os.MkdirAll(getDataDir(), 0755)
	data, err := os.ReadFile(getCountsFile())
	if err != nil {
		counts = Counts{}
		return
	}
	json.Unmarshal(data, &counts)
}

func saveCounts() {
	data, _ := json.MarshalIndent(counts, "", "  ")
	os.WriteFile(getCountsFile(), data, 0644)
}

func main() {
	loadCounts()

	http.HandleFunc("/api/downloads", handleDownloads)
	http.HandleFunc("/api/downloads/", handleIncrement)

	log.Println("Counter API running on " + getPort())
	log.Fatal(http.ListenAndServe(getPort(), nil))
}

func handleDownloads(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		return
	}

	mu.Lock()
	defer mu.Unlock()

	json.NewEncoder(w).Encode(counts)
}

func handleIncrement(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if r.Method == "OPTIONS" {
		return
	}

	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	arch := r.URL.Path[len("/api/downloads/"):]
	if arch == "" {
		http.Error(w, "Architecture required", 400)
		return
	}

	mu.Lock()
	defer mu.Unlock()

	switch arch {
	case "pc":
		counts.PC++
	case "pi":
		counts.Pi++
	case "cloud":
		counts.Cloud++
	default:
		http.Error(w, "Unknown architecture", 400)
		return
	}

	saveCounts()
	json.NewEncoder(w).Encode(counts)
}
