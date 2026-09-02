# Configuration for the validation runners (tools/*.ps1, from the agentic-godot-validation kit).
# The Godot project lives under src/, which the kit's auto-detection (repo root or client/)
# does not find.
@{
    AppName       = 'tactical-battle-kit'
    ClientRoot    = 'src'
    ArtifactsRoot = 'src/artifacts'
}
