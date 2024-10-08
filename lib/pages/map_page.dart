import 'package:circular_menu/circular_menu.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mini_project_five/pages/information.dart';
import 'package:mini_project_five/pages/loading.dart';
import 'dart:async';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:mini_project_five/pages/location_service.dart';
import 'package:mini_project_five/screen/morning_bus.dart';
import 'package:mini_project_five/screen/afternoon_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;
import 'package:flutter_map/src/layer/polygon_layer/polygon_layer.dart';
import 'package:mini_project_five/pages/settings.dart';
import 'package:mini_project_five/pages/news_announcement.dart';
import 'package:mini_project_five/screen/afternoon_service.dart';
import 'package:mini_project_five/pages/information.dart';
import 'package:mini_project_five/pages/mqtt.dart';

class Map_Page extends StatefulWidget {
  const Map_Page({super.key});

  @override
  State<Map_Page> createState() => _Map_PageState();
}

class _Map_PageState extends State<Map_Page> with WidgetsBindingObserver {
  LocationService _locationService = LocationService();
  MQTT_Connect _mqttConnect = MQTT_Connect();
  Timer? _timer;
  int selectedBox = 0;
  LatLng? _currentP;
  double _heading = 0.0;
  List<LatLng> routepoints = [];
  int service_time = 9;
  bool ignoring = false;
  bool _isDarkMode = false;
  LatLng? Bus_Location;
  DateTime currentTime = DateTime.now();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize the MQTT connection
    _mqttConnect = MQTT_Connect();
    _mqttConnect.createState().initState(); // Assuming you have this function in your MQTT_Connect class.

    // Subscribe to the ValueNotifier for bus location updates
    MQTT_Connect.busLocationNotifier.addListener(() {
      setState(() {
        Bus_Location = MQTT_Connect.busLocationNotifier.value;
      });
    });

    // Other initializations like location services
    _locationService.BusData();
    _locationService.getCurrentLocation().then((location) {
      setState(() {
        _currentP = location;
      });
    });
    _locationService.initCompass((heading) {
      setState(() {
        _heading = heading;
      });
    });

    // Update location periodically
    _timer = Timer.periodic(Duration(seconds: 2), (Timer t) => _getLocation());
  }


  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }


  void updateSelectedBox(int selectedBox) {
    setState(() {
      this.selectedBox = selectedBox;
      if (selectedBox == 1){
        if(currentTime.hour >= 7 && currentTime.hour <10){
          fetchRoute(LatLng(1.3356931749752623, 103.78289498576169), LatLng(1.327467, 103.776263), LatLng(1.3327930713846318, 103.77771893587253)); //Morning Route
        }
        else if (currentTime.hour >= 15 && currentTime.hour <=19)
          fetchRoute(LatLng(1.3327930713846318, 103.77771893587253),LatLng(1.3310003377322532, 103.79773782712023), LatLng(1.3359291665604225, 103.78307744418207)); //Afternoon Route
      }
      else if (selectedBox == 2) {
        if (currentTime.hour >= 7 && currentTime.hour < 10) {
          fetchRoute(LatLng(1.314905, 103.765182), LatLng(1.318088, 103.763798),
              LatLng(1.3327930713846318, 103.77771893587253)); //Morning Route
        }
        else if (currentTime.hour >= 15 && currentTime.hour <=19) {
          fetchRoute(LatLng(1.3327930713846318, 103.77771893587253), LatLng(1.313663, 103.765765),LatLng(1.314905, 103.765182)); //Afternoon Route
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    //subscription.cancel();
    //client.disconnect();
    super.dispose();
  }

  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (state == AppLifecycleState.resumed) {
  //     _connect(); // Reconnect when app resumes
  //   }
  // }

  void _getLocation() {
    _locationService.getCurrentLocation().then((location) {
      setState(() {
        _currentP = location;
      });
    });
  }

  Widget _buildCompass() {
    return _locationService.buildCompass(_heading, _currentP!);
  }

  Future<void> fetchRoute(LatLng start, LatLng wayPoint1, LatLng destination) async {
    var url = Uri.parse(
        'http://router.project-osrm.org/route/v1/car/${start.longitude},${start
            .latitude};${wayPoint1.longitude},${wayPoint1.latitude};${destination.longitude},${destination
            .latitude}?overview=simplified&steps=true');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        routepoints.clear();
        routepoints.add(start);
        var data = jsonDecode(response.body);

        if (data['routes'] != null) {
          String encodedPolyline = data['routes'][0]['geometry'];
          List<LatLng> decodedCoordinates = PolylinePoints()
              .decodePolyline(encodedPolyline)
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          routepoints.addAll(decodedCoordinates);
        }
      });
    }
  }

  void _onPanelOpened() {
    setState(() {
      ignoring = true;
    });
  }

  void _onPanelClosed() {
    setState(() {
      ignoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget servicePage;

    if (currentTime.hour < service_time) {
      servicePage = BusPage(updateSelectedBox: updateSelectedBox, isDarkMode: _isDarkMode);
    } else {
      servicePage = AfternoonService(updateSelectedBox: updateSelectedBox, isDarkMode: _isDarkMode);
    }

    return Scaffold(
      body: _currentP == null ? Loading(isDarkMode: _isDarkMode) : Stack(
        children: [
          // FlutterMap is at the bottom of the stack
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(_currentP!.latitude, _currentP!.longitude),
              initialZoom: 18,
              initialRotation: _heading,
              interactionOptions: const InteractionOptions(
                  flags: ~InteractiveFlag.doubleTapZoom),
            ),
            // nonRotatedChildren: [
            //   SimpleAttributionWidget(
            //       source: Text('OpenStreetMap contributors'))
            // ],
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.fleaflet.flutter_map.example',
                tileBuilder: _isDarkMode == true
                    ? (BuildContext context, Widget tileWidget, TileImage tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      -1,  0,  0, 0, 255,
                      0, -1,  0, 0, 255,
                      0,  0, -1, 0, 255,
                      0,  0,  0, 1,   0,
                    ]),
                    child: tileWidget,
                  );
                }
                    : null,
              ),
              PolylineLayer(
                //polylineCulling: false,
                  polylines: [
                    Polyline(
                      points: routepoints,
                      color: Colors.blue,
                      strokeWidth: 5,
                      // Define a single StrokePattern
                      pattern: StrokePattern.dashed(
                        segments: [1, 7],
                        patternFit: PatternFit.scaleUp,
                      ),
                    )
                  ]),
              _buildCompass(),
              MarkerLayer(markers: [
                Marker(
                    point: Bus_Location ??
                        LatLng(1.3323127398440282, 103.774728443874),
                    child: Icon(
                      Icons.circle_sharp,
                      color: Colors.blueAccent,
                      size: 23,
                    )
                )
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 30.0, 10.0, 0),
                child: CircularMenu(
                    alignment: Alignment.topRight,
                    radius: 80.0,
                    toggleButtonColor: Colors.cyan,
                    curve: Curves.easeInOut,
                    items: [
                      CircularMenuItem(
                          color: Colors.yellow[300],
                          iconSize: 30.0,
                          margin: 10.0,
                          padding: 10.0,
                          icon: Icons.info_rounded,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Information_Page(
                                  isDarkMode: _isDarkMode,
                                ),
                              ),
                            );
                          }),
                      CircularMenuItem(
                          color: Colors.green[300],
                          iconSize: 30.0,
                          margin: 10.0,
                          padding: 10.0,
                          icon: Icons.settings,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Settings(
                                  isDarkMode: _isDarkMode,
                                  onThemeChanged: _toggleTheme,
                                ),
                              ),);
                          }),
                      CircularMenuItem(
                          color: Colors.pink[300],
                          iconSize: 30.0,
                          margin: 10.0,
                          padding: 10.0,
                          icon: Icons.newspaper,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => NewsAnnouncement(
                                  isDarkMode: _isDarkMode,
                                ),
                              ),
                            );
                          }),
                    ]
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 40.0, 0.0, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ClipOval(
                    child: Image.asset(
                      'images/logo.jpeg',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // SlidingUpPanel is overlaid on top of the map
          SlidingUpPanel(
            onPanelOpened: _onPanelOpened,
            onPanelClosed: _onPanelClosed,
            panelBuilder: (controller) {
              return Container(
                color: _isDarkMode ? Colors.lightBlue[900] : Colors.lightBlue[100],
                child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'MooBus on-demand',
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ),
                        // IconButton(onPressed: () {
                        // print('printing buslocationnotifier outside: ${MQTT_Connect.busLocationNotifier}');
                        // print('printing timenotifier outside: ${MQTT_Connect.timeNotifier}');
                        // print('printing speednotifier outside: ${MQTT_Connect.speedNotifier}');
                        // }, icon: Icon(Icons.emergency)),
                        servicePage,
                        SizedBox(height: 16),
                        Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: NewsAnnouncementWidget(isDarkMode: _isDarkMode)
                        ),
                        SizedBox(height: 20),
                      ],
                    )
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

