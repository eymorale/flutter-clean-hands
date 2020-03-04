import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:geocoder/geocoder.dart';

// constants in shareable preferences
final homeLocationKey = 'my_home_location';
final homeLatitudeKey = 'my_home_latitude';
final homeLongitudeKey = 'my_home_longitude';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
const kGoogleApiKey = 'YOUR_API_KEY';
GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: kGoogleApiKey);

void main() async {
  runApp(MyApp());

  // Initialize local notifications plugin
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  var initializationSettingsIOS = IOSInitializationSettings();
  var initializationSettings =
      InitializationSettings(null, initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clean Hands!!',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Clean Hands!!'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // home page of the widget - state created from _MyHomePageState

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _homeLocation = 'Unknown';
  double _homeLatitude;
  double _homeLongitude;

  // called on initState to retrieve saved values from shared preferences
  Future<Map> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final result = {
      'homeLocation': prefs.getString(homeLocationKey) ?? 'Unknown',
      'homeLatitude': prefs.getDouble(homeLatitudeKey) ?? null,
      'homeLongitude': prefs.getDouble(homeLongitudeKey) ?? null
    };
    return result;
  }

  // update values in shared preferences
  Future<void> _saveHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('my_home_location', _homeLocation);
    prefs.setDouble('my_home_latitude', _homeLatitude);
    prefs.setDouble('my_home_longitude', _homeLongitude);
  }

  // this is called when user selects new address from the Google PlacesAutoComplete widget
  Future<Null> displayPrediction(Prediction p) async {
    if (p != null) {
      PlacesDetailsResponse detail =
          await _places.getDetailsByPlaceId(p.placeId);
      // var address = await Geocoder.local.findAddressesFromQuery(p.description);

      // update the state and update the values in shared preferences for persistence
      setState(() {
        _homeLocation = p.description;
        _homeLatitude = detail.result.geometry.location.lat;
        _homeLongitude = detail.result.geometry.location.lng;
      });
      await _saveHomeLocation();

      // update the geofence
      _addGeofence();
    }
  }

  // error handler for PlacesAutoComplete
  void onError(PlacesAutocompleteResponse response) {
    print('onError:');
    print(response.errorMessage);
  }

  // add background geolocation geofence
  void _addGeofence() {
    bg.BackgroundGeolocation.addGeofence(bg.Geofence(
      identifier: 'HOME',
      radius: 150,
      latitude: _homeLatitude,
      longitude: _homeLongitude,
      notifyOnEntry: true, // only notify on entry
      notifyOnExit: false,
      notifyOnDwell: false,
      loiteringDelay: 30000, // 30 seconds
    )).then((bool success) {
      print('[addGeofence] success with $_homeLatitude and $_homeLongitude');
    }).catchError((error) {
      print('[addGeofence] FAILURE: $error');
    });
  }

  // background geolocation event handlers
  // triggered whenever a geofence event is detected - in this case when you ENTER a geofence that was added on the app home page
  void _onGeofence(bg.GeofenceEvent event) {
    print('onGeofence $event');
    var platformChannelSpecifics =
        NotificationDetails(null, IOSNotificationDetails());
    flutterLocalNotificationsPlugin
        .show(0, 'Welcome home!', 'Don\'t forget to wash your hands!', platformChannelSpecifics)
        .then((result) {})
        .catchError((onError) {
      print('[flutterLocalNotificationsPlugin.show] ERROR: $onError');
    });
  }

  @override
  void initState() {
    super.initState();
    // This is the proper place to make the async calls
    // This way they only get called once

    // read saved values from shared preferences and assign them to the app variables
    _init().then((result) {
      setState(() {
        _homeLocation = result['homeLocation'];
        _homeLatitude = result['homeLatitude'];
        _homeLongitude = result['homeLongitude'];
      });

      // add geofence if coordinates are set
      if (_homeLatitude != null && _homeLongitude != null) {
        _addGeofence();
      }
    });

    // set background geolocation events
    bg.BackgroundGeolocation.onGeofence(_onGeofence);

    // Configure the plugin and call ready
    bg.BackgroundGeolocation.ready(bg.Config(
            desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
            distanceFilter: 10.0,
            stopOnTerminate: false,
            startOnBoot: true,
            debug: false, // true
            logLevel: bg.Config.LOG_LEVEL_OFF // bg.Config.LOG_LEVEL_VERBOSE
            ))
        .then((bg.State state) {
      if (!state.enabled) {
        // start the plugin
        // bg.BackgroundGeolocation.start();

        // start geofences only
        bg.BackgroundGeolocation.startGeofences();
      }
    });
  }

  // rerun every time setState is called - Flutter framework is optimized for this
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        // position the column of widgets in the center
        child: Column(
          // vertically align widets
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image(image: AssetImage('assets/wash-hands-100.png')),
            SizedBox(height: 50),
            Text(
              'Remember to wash your hands at:',
            ),
            SizedBox(height: 10),
            Padding(
                padding: EdgeInsets.fromLTRB(20, 5, 20, 20),
                child: Text(
                  '$_homeLocation',
                  style: Theme.of(context).textTheme.display1,
                  textAlign: TextAlign.center,
                )),
            SizedBox(height: 10),
            Text(
              '$_homeLatitude, $_homeLongitude',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // pop up google address search widget and call display prediction after user makes selection
          Prediction p = await PlacesAutocomplete.show(
              context: context,
              apiKey: kGoogleApiKey,
              onError: onError,
              mode: Mode.overlay);
          await displayPrediction(p); // call to update user selection values
        },
        tooltip: 'Set Home Location',
        child: Icon(Icons.add),
      ),
    );
  }
}
