# Game Factory environment — source this in every pipeline script
export TOOLS=/home/claude/tools
export GODOT=$TOOLS/godot
export JAVA_HOME=$TOOLS/jdk17
export ANDROID_HOME=$TOOLS/android-sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH
export FACTORY=/home/claude/godot

# Android release signing — kept out of export_presets.cfg (which lives in the project)
if [ -f "$TOOLS/secrets/keystore.env" ]; then . "$TOOLS/secrets/keystore.env"; fi
