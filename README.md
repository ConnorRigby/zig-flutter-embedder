# Zig Flutter Embedder

## Usage

The setup for this is currently sort of convoluted. TODO: automate this process in the future..

* [Get Zig](https://ziglang.org/download/)
* [Get Flutter](https://flutter.dev/)
* Get a statically linked library for your platform: `find / -name "engine.version"`
* Unzip that into this directory: `unzip flutter_embedder`
* Create a new flutter app (or copy your own): `flutter create myapp`
* Create a bundle: `cd myapp && flutter build bundle`
* `zig build run`

## Screenshots and Demos

TODO: add more examples

![Flutter Demo Home Page](https://cdn.discordapp.com/attachments/1043999192789549076/1095814780217991198/image.png)
![Flutter Demo Home Page](https://cdn.discordapp.com/attachments/1043999192789549076/1095815087245242388/Screencast_from_2023-04-12_14-57-34.webm)

## Docs, Links, etc

These links helped me, but to be quite honest, only in spirit. They contain almost no useful information.

* [unhelpfully empty official documentation](https://docs.flutter.dev/embedded)
* [annoyingly unhelpful official Discord](https://discord.com/invite/N7Yshp4)
* [woefully incomplete official embedder example](https://github.com/flutter/engine/tree/main/examples/glfw#flutter-embedder-engine-glfw-example)
