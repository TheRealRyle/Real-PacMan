"""Run the app's actual parcours models and store under Swift Testing, without a simulator.
Creates an isolated temporary Swift package; does not alter the Xcode project.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
package = Path(tempfile.mkdtemp(prefix="realpacman-tests-"))
sources = package / "Sources/ParcoursCore"
tests = package / "Tests/ParcoursCoreTests"
sources.mkdir(parents=True)
tests.mkdir(parents=True)
files = [
    "Routes/GameRoute.swift", "Routes/RouteCoordinate.swift", "Routes/Pellet.swift", "Routes/OfflineMapBounds.swift",
    "Gameplay/GameSession.swift", "Gameplay/GameArchive.swift", "Gameplay/GameStore.swift",
    "Gameplay/ModeProgress.swift", "Gameplay/GhostState.swift", "Gameplay/GhostChase.swift",
    "Gameplay/DemoSession.swift", "Gameplay/DemoDirection.swift",
    "Gameplay/GameplayRules.swift", "Gameplay/PelletGuidance.swift", "Gameplay/ServerEndpoint.swift",
    "Parcours/ParcoursMode.swift", "Parcours/ParcoursJunction.swift", "Parcours/ParcoursPath.swift",
    "Parcours/ParcoursDefinition.swift", "Parcours/ParcoursValidationError.swift",
    "Parcours/ParcoursCandidate.swift", "Parcours/ParcoursCatalogue.swift"
]
for file in files:
    shutil.copy2(root / "Real Pacman" / file, sources / Path(file).name)
shutil.copy2(root / "Tests/ParcoursTests.swift", tests)
shutil.copy2(root / "Tests/DemoSessionTests.swift", tests)
shutil.copy2(root / "Tests/GameplayFeatureTests.swift", tests)
shutil.copy2(root / "Tests/ServerIntegrationTests.swift", tests)
shutil.copy2(root / "Tests/ModeProgressTests.swift", tests)
shutil.copy2(root / "Tests/CatalogueVersionTests.swift", tests)
shutil.copy2(root / "Real Pacman/ParcoursData/verney-draft.json", tests)
(package / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ParcoursChecks", platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ParcoursCore"),
        .testTarget(name: "ParcoursCoreTests", dependencies: ["ParcoursCore"],
                    resources: [.copy("verney-draft.json")])
    ])
''')
print("Testing actual app sources in", package, flush=True)
subprocess.run(["swift", "test", "--package-path", str(package)], check=True)

# Keep the pre-existing GPS/persistence regression executable running as well.
regression = package / "game-store-checks"
subprocess.run(["swiftc", "-module-cache-path", str(package / "ModuleCache"),
                *[str(sources / Path(file).name) for file in files],
                str(root / "Tests/GameStoreChecks.swift"), "-o", str(regression)], check=True)
subprocess.run([str(regression)], check=True)
