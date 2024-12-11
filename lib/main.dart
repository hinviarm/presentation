import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:volume_watcher/volume_watcher.dart';
import 'package:wakelock/wakelock.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:dart_numerics/dart_numerics.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flame_tiled/flame_tiled.dart';

import 'KalmanFilter.dart';
import 'user.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Flame.device.setOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight
  ]);
  runApp(GameWidget(game: MyGame()));
}

enum TtsState { playing, stopped, paused, continued }

class MyGame extends FlameGame
    with
        HasGameRef,
        HasCollisionDetection,
        TapDetector,
        ScrollDetector,
        ScaleDetector,
        DragCallbacks {
  bool _isDragged = false;
  final user = User(position: Vector2(0.0, 0.0));
  final double characterSize = 200.0;
  double altitude = 0.0;
  double longitude = 0.0;
  double latitude = 0.0;
  double distance = 0.0;
  double longitudeInitial = 0.0;
  double latitudeInitial = 0.0;
  double xInitial = 0.0;
  double yInitial = 0.0;
  Vector2 vectTmp = Vector2(0.0, 0.0);

  //KalmanFilter kf = new KalmanFilter(0.1, 1.4, 1.0, 0);
  List<List> pairsList = [[]];

  late TiledComponent component;
  SpriteComponent destinationComp = SpriteComponent();

  late Location location;
  StreamSubscription<LocationData>? locationSubscription;

  List<double> latitudeList = [];
  List<double> longitudeList = [];
  int windowSize = 5;  // Taille de la fenêtre pour la moyenne
  Vector2 currentPosition = Vector2.zero();
  // Pas touche
  double distance1 = 0.0;
  double distance2 = 0.0;
  double distance3 = 0.0;
  var coordonnee = {'x': 0.0, 'y': 0.0};
  late FlutterTts flutterTts;
  TtsState ttsState = TtsState.stopped;
  KalmanFilter kalmanFilter = KalmanFilter();
  GpsSmoothing gpsSmoothing = GpsSmoothing();
  get isPlaying => ttsState == TtsState.playing;

  get isStopped => ttsState == TtsState.stopped;
  var stopLecture = 0;
  String? language;

  late List<Vector2> points = [];
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  bool musicPlaying = false;

  double direction = 0.0;
  bool premier = true;
  double angle = 0.0;
  double prevValue = 0.0;
  int avance = 0;

  bool direct = false;
  bool execute = false;
  bool trace = false;
  bool neg = false;

  Future<void> initPlatformState() async {
    // todo
  }

  initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      print("Playing");
      ttsState = TtsState.playing;
    });

    flutterTts.setCompletionHandler(() {
      print("Complete");
      ttsState = TtsState.stopped;
    });

    flutterTts.setCancelHandler(() {
      print("Cancel");
      ttsState = TtsState.stopped;
    });

    flutterTts.setErrorHandler((msg) {
      print("error: $msg");
      ttsState = TtsState.stopped;
    });
  }

  Future _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  // Méthode pour ajuster le volume
  Future<void> setVolume(double newVolume) async {
    volume = newVolume.clamp(0.0, 1.0);
    await flutterTts.setVolume(volume);
  }

  // Méthode pour gérer les changements de volume
  void onVolumeChange(double newVolume) {
    setVolume(newVolume);
  }

  Future _speak(String text) async {
    //await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (text != null) {
      if (text!.isNotEmpty) {
        await flutterTts.speak(text!);
      }
    }
  }

  Future _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }
  double getSmoothedLatitude(double newLatitude) {
    if (latitudeList.length == windowSize) {
      latitudeList.removeAt(0);
    }
    latitudeList.add(newLatitude);

    double sum = latitudeList.reduce((a, b) => a + b);
    return sum / latitudeList.length;
  }

  double getSmoothedLongitude(double newLongitude) {
    if (longitudeList.length == windowSize) {
      longitudeList.removeAt(0);
    }
    longitudeList.add(newLongitude);

    double sum = longitudeList.reduce((a, b) => a + b);
    return sum / longitudeList.length;
  }

// Fonction pour convertir la latitude et la longitude en coordonnées du jeu
  Vector2 convertLatLonToGameCoordinates(double longt, double latt) {
    const double earthRadius =
        6378137.0; // Rayon de la terre en mètres (pour la projection Mercator)

    double long = longt - ((longt * 10000).truncate() / 10000);
    double lat = latt - ((latt * 10000).truncate() / 10000);
    // Projection Mercator simplifiée
    double x =
        earthRadius * long * pi / 180.0; // Convertir longitude en radians
    double y = earthRadius *
        log(tan(pi / 4.0 + lat * pi / 360.0)); // Convertir latitude en radians
    debugPrint(
        'Coordonnee x ' + x.toString() + ' Coordonnee y ' + y.toString());

    //double xMod = (x - ((x / 100).truncate() * 100)) * 10;
    double xMod = x * 20;
    //double yMod = (y - ((y / 100).truncate() * 100)) * 10;
    double yMod = y * 20;
    debugPrint('Coordonnee Modifié x ' +
        xMod.toString() +
        ' Coordonnee Modifié y ' +
        yMod.toString());
    // Tu peux ensuite ajuster ces coordonnées en fonction de ton jeu, par exemple en recentrant le tout
    // Ici, on recentre autour du centre de l'écran pour que la carte soit centrée
    return Vector2(xMod, -yMod); // Diviser pour ajuster l'échelle
  }

  void stopCameraFollow() {
    // Remove the FollowBehavior from the camera's viewfinder
    camera.viewfinder.children.whereType<FollowBehavior>().forEach((behavior) {
      camera.viewfinder.remove(behavior);
    });
  }

  void clampZoom() {
    camera.viewfinder.zoom = camera.viewfinder.zoom.clamp(0.05, 3.0);
  }

  static const zoomPerScrollUnit = 0.02;

  @override
  void onScroll(PointerScrollInfo info) {
    camera.viewfinder.zoom +=
        info.scrollDelta.global.y.sign * zoomPerScrollUnit;
    clampZoom();
  }

  late double startZoom;

  @override
  void onScaleStart(ScaleStartInfo info) {
    startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final currentScale = info.scale.global;

    if (!currentScale.isIdentity()) {
      camera.viewfinder.zoom = startZoom * currentScale.y;
      clampZoom();
    } else {
      final delta = info.delta.global;
      camera.viewfinder.position.translate(-delta.x, -delta.y);
    }
  }

  @override
  void onTapDown(TapDownInfo info) {
    super.onTapDown(info);
    _isDragged = false;
    camera.follow(user);
  }

  @override
  Future<void> onLoad() async {
    await images.loadAllImages();

    component = await TiledComponent.load('Construction.tmx', Vector2.all(16));
    component.size = Vector2(size[0], size[1] - 40);
    world.add(component);

    final coordonnees = component.tileMap.getLayer<ObjectGroup>('Coordonnees');
    for (final individu in coordonnees!.objects) {
      if (individu.class_ == 'User') {
        xInitial = individu.x;
        yInitial = individu.y;
        user.position = Vector2(xInitial, yInitial);
        world.add(user);
        camera.viewfinder.anchor = Anchor.center;
      }
    }

    camera.follow(user);

    super.onLoad();
    initTts();
    VolumeWatcher.addListener(onVolumeChange);
    // initialize flame audio background music
    FlameAudio.bgm.initialize();
    // Initialiser la localisation GPS
    location = Location();

    // Demander les permissions et démarrer la localisation
    _initLocationService();
  }

// Méthode pour initialiser les services de localisation
  void _initLocationService() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) return;
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) return;
    }

    // Commencer à écouter les changements de position GPS
    locationSubscription =
        location.onLocationChanged.listen((LocationData locationData) {
      _onLocationChanged(locationData);
    });
  }

  // Méthode pour déplacer le joueur selon la position GPS
  void _onLocationChanged(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      if (longitude == 0.0 && latitude == 0.0) {
        longitudeInitial = locationData.longitude!;
        latitudeInitial = locationData.latitude!;
      }
      altitude = locationData.altitude!;
      longitude = locationData.longitude!;
      latitude = locationData.latitude!;
      //double filteredLatitude = kalmanFilter.filterLatitude(latitude);
      //double filteredLongitude = kalmanFilter.filterLongitude(longitude);
      //double smoothedLatitude = getSmoothedLatitude(latitude);
      //double smoothedLongitude = getSmoothedLongitude(longitude);
      vectTmp = gpsSmoothing.getSmoothedPosition(convertLatLonToGameCoordinates(longitude, latitude));
    }
  }

  void lecture(String texte) async {
    await Future.delayed(Duration(seconds: 8), () => _speak(texte));
  }

  @override
  void update(double dt) {
    initPlatformState();
    super.update(dt);
    //user.x = 10 * dt;
    // Interpolation entre les deux positions
    if ((vectTmp.x - user.x).abs() > 10) {
      if (vectTmp.x > user.x) {
        lecture("Vous allez à droite");
      } else if (vectTmp.x < user.x) {
        lecture("Vous allez à gauche");
      }
    }

    if ((vectTmp.y - user.y).abs() > 10) {
      if (vectTmp.y > user.y) {
        lecture("Vous avancez");
        if(direct) {
          avance++;
        } else {
          avance--;
        }
        if(avance == 10 || avance == -10){
          camera.viewfinder.angle += pi;
          user.angle += pi;
        }
      } else if (vectTmp.y < user.y) {
        lecture("Vous allez dans la direction opposée");

        if(direct == true){
          direct = false;
          avance = 0;
        } else {
          direct = true;
          avance = 0;
        }

      }
    }
    user.position.lerp(vectTmp, 0.1);

    //user.position += gpsSmoothing.getSmoothedPosition(Vector2(10000000 * (longitude - longitudeInitial), 10000000 * (latitude - latitudeInitial)));
    //user.y = 10 * dt;
    xInitial = user.x;
    yInitial = user.y;
    debugPrint('longitude :' +
        longitude.toString() +
        ' & ' +
        longitudeInitial.toString());
    debugPrint('latitude :' +
        latitude.toString() +
        ' & ' +
        latitudeInitial.toString());
    longitudeInitial = longitude;
    latitudeInitial = latitude;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    Wakelock.enable();
    /*if (!musicPlaying) {
      FlameAudio.bgm.play('music.ogg');
      musicPlaying = true;
    }
     */
  }

  @override
  void onRemove() {
    super.onRemove();
    _stop();
    world.removed;
    locationSubscription?.cancel();
    VolumeWatcher.removeListener(onVolumeChange as int?);
  }

  @override
  void onDragStart(DragStartEvent event) => _isDragged = true;

  @override
  void onDragUpdate(DragUpdateEvent event) async {
    camera.stop();
    camera.viewfinder.position += event.delta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    // Todo
  }
}

class GpsSmoothing {
  final List<Vector2> recentPositions = [];
  final int maxSamples = 5; // Limite des échantillons
  //KalmanFilter kf = new KalmanFilter(0.1, 1.4, 1.0, 0);

  Vector2 getSmoothedPosition(Vector2 newPosition) {
    // Ajouter la nouvelle position GPS à la liste
    recentPositions.add(newPosition);

    // Limiter le nombre d'échantillons stockés
    if (recentPositions.length > maxSamples) {
      recentPositions.removeAt(0); // Retirer l'échantillon le plus ancien
    }

    // Calculer la moyenne des positions
    double averageX = recentPositions.map((p) => p.x).reduce((a, b) => a + b) /
        recentPositions.length;
    double averageY = recentPositions.map((p) => p.y).reduce((a, b) => a + b) /
        recentPositions.length;

    //return Vector2(kf.getFilteredValue(averageX), kf.getFilteredValue(averageY));
    return Vector2(averageX, averageY);
  }
}
