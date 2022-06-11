package;

import kha.System;

class Main {
	public static function main() {
		System.start({title: "WorkerKha", width: 640, height: 480}, function (_) {
			var worker = new WorkerKha();
			System.notifyOnFrames(worker.render);

			//WorkerKha.instance.load("Checkouts/800b9da2e687c6b11499fa339d195929c92b54b9/build/html5worker/khaworker.js");
		});
	}
}
