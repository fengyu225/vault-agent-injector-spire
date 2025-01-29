package main

import (
	"database/sql"
	"encoding/json"
	"fmt"
	_ "github.com/lib/pq"
	"log"
	"os"
	"time"
)

type DBConfig struct {
	Database string `json:"database"`
	Host     string `json:"host"`
	Password string `json:"password"`
	Port     string `json:"port"`
	Username string `json:"username"`
}

type User struct {
	ID        int
	Username  string
	Email     string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Order struct {
	ID          int
	UserID      int
	OrderNumber string
	TotalAmount float64
	Status      string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

func loadConfig() (*DBConfig, error) {
	configData, err := os.ReadFile("/vault/secrets/config")
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %v", err)
	}

	var config DBConfig
	if err := json.Unmarshal(configData, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %v", err)
	}

	return &config, nil
}

func main() {
	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		config.Host, config.Port, config.Username, config.Password, config.Database)

	log.Printf("Connecting to database at %s...", config.Host)

	// Connect to database
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	// Test connection
	err = db.Ping()
	if err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}
	log.Println("Successfully connected to database")

	for {
		// Query users
		users, err := getUsers(db)
		if err != nil {
			log.Fatalf("Failed to get users: %v", err)
		}

		// Print users
		fmt.Println("\nUsers:")
		fmt.Println("----------------------------------------")
		for _, user := range users {
			fmt.Printf("ID: %d\nUsername: %s\nEmail: %s\nCreated At: %v\nUpdated At: %v\n\n",
				user.ID, user.Username, user.Email, user.CreatedAt, user.UpdatedAt)
		}

		// Query orders
		orders, err := getOrders(db)
		if err != nil {
			log.Fatalf("Failed to get orders: %v", err)
		}

		// Print orders
		fmt.Println("\nOrders:")
		fmt.Println("----------------------------------------")
		for _, order := range orders {
			fmt.Printf("Order ID: %d\nUser ID: %d\nOrder Number: %s\nTotal Amount: $%.2f\nStatus: %s\nCreated At: %v\nUpdated At: %v\n\n",
				order.ID, order.UserID, order.OrderNumber, order.TotalAmount, order.Status, order.CreatedAt, order.UpdatedAt)
		}

		time.Sleep(1 * time.Second)
	}
}

func getUsers(db *sql.DB) ([]User, error) {
	rows, err := db.Query("SELECT id, username, email, created_at, updated_at FROM app.users")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []User
	for rows.Next() {
		var user User
		err := rows.Scan(&user.ID, &user.Username, &user.Email, &user.CreatedAt, &user.UpdatedAt)
		if err != nil {
			return nil, err
		}
		users = append(users, user)
	}
	return users, nil
}

func getOrders(db *sql.DB) ([]Order, error) {
	rows, err := db.Query("SELECT id, user_id, order_number, total_amount, status, created_at, updated_at FROM app.orders")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var orders []Order
	for rows.Next() {
		var order Order
		err := rows.Scan(&order.ID, &order.UserID, &order.OrderNumber, &order.TotalAmount, &order.Status, &order.CreatedAt, &order.UpdatedAt)
		if err != nil {
			return nil, err
		}
		orders = append(orders, order)
	}
	return orders, nil
}
