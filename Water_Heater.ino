#include <WiFi.h>
#include <FirebaseESP32.h>
#include <HTTPClient.h>
#include <OneWire.h>
#include <DallasTemperature.h>


const char* ssid = "*********";    //Enter your WiFi username  
const char* password = "*********"; //Enter your WiFi Password
const String FIREBASE_HOST = "https://water-heater-5999f-default-rtdb.asia-southeast1.firebasedatabase.app/";
const String FIREBASE_AUTH = "vleXi4HzEcAW76W39QuQLsXlTs7VZZERFaztYlWq";

#define ONE_WIRE_BUS 4
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

#define FLOW_SENSOR_PIN 5
volatile int flowPulseCount = 0;
float flowRate = 0.0;

// Current sensor setup (ACS712)
#define CURRENT_SENSOR_PIN 34
float current = 0.0;

// LED pin
#define STATUS_LED 14

void IRAM_ATTR pulseCounter() {
  flowPulseCount++;
}

void setup() {
  Serial.begin(115200);

  sensors.begin();

  pinMode(FLOW_SENSOR_PIN, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(FLOW_SENSOR_PIN), pulseCounter, FALLING);

  pinMode(CURRENT_SENSOR_PIN, INPUT);
  pinMode(STATUS_LED, OUTPUT);

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi");
}

void loop() {
  // Reset pulse count and wait 1 second to measure flow
  flowPulseCount = 0;
  delay(1000);
  flowRate = flowPulseCount / 7.5;

  Serial.print("Water Flow Rate: ");
  Serial.print(flowRate);
  Serial.println(" L/min");

  String heaterStatus = "OFF";

  // Check if water is flowing
  if (flowRate > 0.1) {
    heaterStatus = "ON";
    digitalWrite(STATUS_LED, LOW);  // Turn ON LED (heater ON)

    sensors.requestTemperatures();
    float temperature = sensors.getTempCByIndex(0);
    Serial.print("Temperature: ");
    Serial.println(temperature);

    int sensorValue = analogRead(CURRENT_SENSOR_PIN);
    current = (sensorValue - 512) * (5.0 / 1024.0) * 30;
    Serial.print("Current: ");
    Serial.print(current);
    Serial.println(" A");

    // Send data to Firebase
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = FIREBASE_HOST + "waterHeaterData.json?auth=" + FIREBASE_AUTH;

      String jsonData = "{";
      jsonData += "\"temperature\":" + String(temperature) + ",";
      jsonData += "\"flowRate\":" + String(flowRate) + ",";
      jsonData += "\"current\":" + String(current) + ",";
      jsonData += "\"heaterStatus\":\"" + heaterStatus + "\"";
      jsonData += "}";

      http.begin(url);
      http.addHeader("Content-Type", "application/json");
      int httpResponseCode = http.PUT(jsonData);
      Serial.print("Firebase Response Code: ");
      Serial.println(httpResponseCode);
      http.end();
    } else {
      Serial.println("WiFi Disconnected!");
    }

  } else {
    heaterStatus = "OFF";
    digitalWrite(STATUS_LED, HIGH);  // Turn OFF LED (heater OFF)
    Serial.println("No water flow detected — heater OFF");

    // Optional: send OFF status to Firebase
    if (WiFi.status() == WL_CONNECTED) {
      HTTPClient http;
      String url = FIREBASE_HOST + "waterHeaterData.json?auth=" + FIREBASE_AUTH;

      String jsonData = "{";
      jsonData += "\"temperature\":0,";
      jsonData += "\"flowRate\":" + String(flowRate) + ",";
      jsonData += "\"current\":0,";
      jsonData += "\"heaterStatus\":\"" + heaterStatus + "\"";
      jsonData += "}";

      http.begin(url);
      http.addHeader("Content-Type", "application/json");
      int httpResponseCode = http.PUT(jsonData);
      Serial.print("Firebase Response Code: ");
      Serial.println(httpResponseCode);
      http.end();
    }
  }

  delay(2000);  // Delay before next loop
}
