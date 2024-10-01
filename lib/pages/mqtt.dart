import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTT_Connect extends StatefulWidget {
  const MQTT_Connect({Key? key}) : super(key: key);

  static ValueNotifier<LatLng?> busLocationNotifier = ValueNotifier<LatLng?>(null);
  static ValueNotifier<String?> timeNotifier = ValueNotifier<String?>('');
  static ValueNotifier<double?> speedNotifier = ValueNotifier<double?>(0);

  @override
  _MQTT_ConnectState createState() => _MQTT_ConnectState();
}

class _MQTT_ConnectState extends State<MQTT_Connect> {
  String uniqueID = 'MyPC_24092024';
  final MqttServerClient client = mqtt.MqttServerClient('avkbwu51u3x1o-ats.iot.us-east-2.amazonaws.com', '');
  String statusText = "Status Text";
  bool isConnected = false;
  String topic_loc = 'Bus1Loc';
  String topic_time = 'Bus1Tim';
  String topic_speed = 'Bus1Spd';
  double latitude = 0;
  double longitude = 0;

  @override
  void initState() {
    super.initState();
    _connect(); // Call the async connection method in initState
  }

  // void initializeConnection() {
  // _connect();
  // }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<LatLng?>(
          valueListenable: MQTT_Connect.busLocationNotifier,
          builder: (context, busLocation, _) {
            if (busLocation != null) {
              return MarkerLayer(
                markers: [
                  Marker(
                    point: busLocation,
                    child: const Icon(Icons.add_circle),
                  ),
                ],
              );
            } else {
              return Container(); // Return an empty container if location is null
            }
          },
        ),
      ],
    );
  }

  Future<void> _connect() async {
    try {
      print("Connecting to MQTT server...");
      isConnected = await mqttConnect();
      if (mounted) {
        setState(() {
          statusText = isConnected ? "Connected to MQTT" : "Failed to connect";
        });
      }
    } catch (e) {
      print("Error during connection: $e");
      if (mounted) {
        setState(() {
          statusText = "Error during connection";
        });
      }
    }
  }

  Future<bool> mqttConnect() async {
    print('MQTT Connect');
    try {
      ByteData rootCA = await rootBundle.load('assets/cert/AmazonRootCA1.pem');
      ByteData deviceCert = await rootBundle.load('assets/cert/SurfacePC.cert.pem');
      ByteData privateKey = await rootBundle.load('assets/cert/SurfacePC.private.key');

      SecurityContext context = SecurityContext.defaultContext;
      context.setClientAuthoritiesBytes(rootCA.buffer.asUint8List());
      context.useCertificateChainBytes(deviceCert.buffer.asUint8List());
      context.usePrivateKeyBytes(privateKey.buffer.asUint8List());

      client.securityContext = context;
      client.logging(on: true);
      client.keepAlivePeriod = 20;
      client.port = 8883;
      client.secure = true;
      client.onConnected = onConnected;
      client.onDisconnected = onDisconnected;
      client.pongCallback = pong;

      print('printing client port: ${client.port}');

      print('printing client.update: ${client.updates}');
      print('printing client status1: ${client.connectionStatus}');

      if(client.updates != null) {
      client.updates!.listen(_onMessage);}

      final MqttConnectMessage connMess = MqttConnectMessage()
          .withClientIdentifier(uniqueID)
          .startClean();
      client.connectionMessage = connMess;
      print('printing connMess: ${connMess}');

      print('printing client status2: ${client.connectionStatus}');

      print('waiting client connect');

      print('printing client status3: ${client.connectionStatus}');
      await client.connect();
      if (client.connectionStatus!.state == MqttConnectionState.connected) {
        print("Connected to AWS Successfully!");
        client.subscribe(topic_loc, MqttQos.atMostOnce);
        client.subscribe(topic_speed, MqttQos.atMostOnce);
        client.subscribe(topic_time, MqttQos.atMostOnce);
        client.updates!.listen(_onMessage); // Listen for incoming messages
        return true;
      } else {
        print("Failed to connect, status: ${client.connectionStatus}");
        return false;
      }
    } catch (e) {
      print("Exception during connection: $e");
      return false;
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? messages) {
    print('Inside _onMessage function');
    final MqttPublishMessage recMess = messages![0].payload as MqttPublishMessage;
    print('Printing recMess: ${recMess}');
    final String topic1 = messages[0].topic;
    print('Printing topic: ${topic1}');

    // Extract the payload as a String
    final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
    print('Printing payload: ${payload}');

    if (topic1 == topic_loc) {
      _processLocationMessage(payload);
    } else if (topic1 == topic_time){
      _processTimeMessage(payload);
    } else if (topic1 == topic_speed){
      _processSpeedMessage(payload);
    }
  }
  void _processTimeMessage(String payload){
    print('Inside _processTimeMessage function');

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String time = data['Time'];
      print('Printing time: $time');

      MQTT_Connect.timeNotifier.value = time;
      print('Updating time: ${MQTT_Connect.timeNotifier.value}');
    }
    catch (e){
    print('Caught error : $e');
    }
  }

  void _processSpeedMessage(String payload){
    print('Inside _processSpeedMessage function');

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);
      String speed = data['speed_kmph'];
      print('Printing speed: $speed');

      MQTT_Connect.speedNotifier.value = double.parse(speed);
      print('Updating speed: ${MQTT_Connect.speedNotifier.value}');
    }
    catch (e){
      print('Caught error : $e');
    }
  }

  void _processLocationMessage(String payload) {
    print('Inside _processLocationMessage function');

    try {
      // Decode the JSON payload
      Map<String, dynamic> data = jsonDecode(payload);

      // Extract latitude and longitude
      latitude = double.parse(data['lat']);
      longitude = double.parse(data['lon']);

      LatLng busLocation = LatLng(latitude, longitude);

      // Update the ValueNotifier with the new bus location
      MQTT_Connect.busLocationNotifier.value = busLocation;

      print("Updated Bus Location: $busLocation");
    } catch (e) {
      print("Error processing location message: $e");
    }
  }
void setStatus(String content) {
    setState(() {
      statusText = content;
    });
  }

  void onConnected() {
    setStatus("Client connection was successful");
  }

  void onDisconnected() {
    setStatus("Client Disconnected");
    isConnected = false;
  }

  void pong() {
    print('Ping response client callback invoked');
  }
}
