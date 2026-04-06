package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"golang.org/x/crypto/bcrypt"
)

type RequestRecord struct {
	RequestID string `dynamodbav:"RequestID"`
	Timestamp string `dynamodbav:"Timestamp"`
	Message   string `dynamodbav:"Message"`
}

type Response struct {
	Status     string `json:"status"`
	CPUWorkMs  int64  `json:"cpu_work_ms"`
	DBWriteMs  int64  `json:"db_write_ms"`
	DBReadMs   int64  `json:"db_read_ms"`
	TotalMs    int64  `json:"total_ms"`
	InstanceID string `json:"instance_id"`
}

var (
	dbClient  *dynamodb.Client
	tableName string
)

func init() {
	tableName = os.Getenv("DYNAMODB_TABLE_NAME")
	if tableName == "" {
		tableName = "infra-poc-records"
	}
	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(os.Getenv("AWS_REGION")),
	)
	if err != nil {
		log.Fatalf("AWS設定の読み込みに失敗: %v", err)
	}
	dbClient = dynamodb.NewFromConfig(cfg)
}

func heavyHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}
	totalStart := time.Now()

	// CPU負荷（bcrypt × 1回）
	cpuStart := time.Now()
	bcrypt.GenerateFromPassword([]byte("load-test-password"), bcrypt.DefaultCost)
	cpuMs := time.Since(cpuStart).Milliseconds()

	requestID := fmt.Sprintf("req-%d", time.Now().UnixNano())
	record := RequestRecord{
		RequestID: requestID,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Message:   "heavy API called",
	}

	// DynamoDB 書き込み
	writeStart := time.Now()
	item, _ := attributevalue.MarshalMap(record)
	dbClient.PutItem(context.TODO(), &dynamodb.PutItemInput{
		TableName: aws.String(tableName),
		Item:      item,
	})
	writeMs := time.Since(writeStart).Milliseconds()

	// DynamoDB 読み込み
	readStart := time.Now()
	dbClient.GetItem(context.TODO(), &dynamodb.GetItemInput{
		TableName: aws.String(tableName),
		Key: map[string]types.AttributeValue{
			"RequestID": &types.AttributeValueMemberS{Value: requestID},
		},
	})
	readMs := time.Since(readStart).Milliseconds()

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-cache, no-store")
	json.NewEncoder(w).Encode(Response{
		Status:     "ok",
		CPUWorkMs:  cpuMs,
		DBWriteMs:  writeMs,
		DBReadMs:   readMs,
		TotalMs:    time.Since(totalStart).Milliseconds(),
		InstanceID: os.Getenv("INSTANCE_ID"),
	})
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "OK")
}

// GET /api/info
// CloudFrontキャッシュ効果の検証用エンドポイント
// 起動時刻を返す静的レスポンス → CloudFrontにキャッシュさせる
// キャッシュHIT時はEC2までリクエストが届かないため、この値が変わらなくなる
var serverStartTime = time.Now().UTC().Format(time.RFC3339)

func infoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	// Cache-Controlを設定しない → CloudFrontのTTL設定が有効になる
	json.NewEncoder(w).Encode(map[string]string{
		"status":     "ok",
		"started_at": serverStartTime,
		"instance":   os.Getenv("INSTANCE_ID"),
		"note":       "This response is cacheable by CloudFront",
	})
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	http.HandleFunc("/api/heavy", heavyHandler)
	http.HandleFunc("/api/info", infoHandler)
	http.HandleFunc("/health", healthHandler)
	log.Printf("サーバー起動: ポート %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("起動失敗: %v", err)
	}
}