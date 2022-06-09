package;

import kha.System;

class Main {
	public static function main() {
		System.start({title: "WorkerKha", width: 640, height: 480}, function (_) {
			var worker = new WorkerKha();
			System.notifyOnFrames(worker.render);
		});
	}
}
