import 'dart:async';
import 'main.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

enum PlayerState {
  idle,
  running,
  jumping,
  falling,
  hit,
  appearing,
  disappearing
}

class User extends SpriteAnimationGroupComponent
    with HasGameRef<MyGame>, KeyboardHandler, CollisionCallbacks {
  String character = 'Ninja Frog';
  late final SpriteAnimation idleAnimation;
  final double stepTime = 0.05;

  User({
    position,
    //this.character = 'Ninja Frog',
  }) : super(position: position);

  @override
  FutureOr<void> onLoad() {
    _loadAllAnimations();
    // debugMode = true;
/*
    startingPosition = Vector2(position.x, position.y);

    add(RectangleHitbox(
      position: Vector2(hitbox.offsetX, hitbox.offsetY),
      size: Vector2(hitbox.width, hitbox.height),
    ));

 */
    return super.onLoad();
  }
  void _loadAllAnimations(){
    idleAnimation = SpriteAnimation.fromFrameData(game.images.fromCache('tiledFree/Main Characters/Ninja Frog/Idle (32x32).png'),
    SpriteAnimationData.sequenced(amount: 11, stepTime: stepTime, textureSize: Vector2.all(32)));
    animations = {
      PlayerState.idle: idleAnimation
    };
    current = PlayerState.idle;
  }
}