package;

import kha.System;

class Main {
	public static function main() {
		System.init({title: "WorkerKha", width: 640, height: 480}, function () {
			var worker = new WorkerKha();
			System.notifyOnRender(worker.render);
		});
	}
}
