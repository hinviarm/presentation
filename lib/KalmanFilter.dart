class KalmanFilter {
  double _lastEstimateLatitude = 0.0;
  double _lastEstimateLongitude = 0.0;
  double _lastErrorEstimate = 1.0;
  double q = 0.01; // Process noise
  double r = 0.1;  // Measurement noise

  // Filtrage de la latitude
  double filterLatitude(double measuredLatitude) {
    double kalmanGain = _lastErrorEstimate / (_lastErrorEstimate + r);
    _lastEstimateLatitude = _lastEstimateLatitude + kalmanGain * (measuredLatitude - _lastEstimateLatitude);
    _lastErrorEstimate = (1 - kalmanGain) * _lastErrorEstimate + q;
    return _lastEstimateLatitude;
  }

  // Filtrage de la longitude
  double filterLongitude(double measuredLongitude) {
    double kalmanGain = _lastErrorEstimate / (_lastErrorEstimate + r);
    _lastEstimateLongitude = _lastEstimateLongitude + kalmanGain * (measuredLongitude - _lastEstimateLongitude);
    _lastErrorEstimate = (1 - kalmanGain) * _lastErrorEstimate + q;
    return _lastEstimateLongitude;
  }
}
