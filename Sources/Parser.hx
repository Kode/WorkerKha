package;

using StringTools;

class Func {
	public var name: String;
	public var parameters: Array<String>;
	public var body: String;

	public function new() {
		parameters = [];
	}
}

class Klass {
	public var name: String;
	public var internal_name: String;
	public var methods: Map<String, Func>;
	public var functions: Map<String, Func>;

	public function new() {
		methods = new Map();
		functions = new Map();
	}
}

enum ParseMode {
	ParseRegular;
	ParseMethods;
	ParseMethod;
	ParseFunction;
}

class Parser {
	static var classes: Map<String, Klass> = new Map();

	public static function parse(infile: String) {
		var types = 0;
		var mode: ParseMode = ParseRegular;
		var currentClass: Klass = null;
		var currentFunction: Func = null;
		var currentBody = "";
		var brackets = 1;
		
		var lines = infile.split("\n");
		for (line in lines) {
			switch (mode) {
				case ParseRegular: {
					if (line.endsWith(".prototype = {") || line.indexOf(".prototype = $extend(") >= 0) { // parse methods
						mode = ParseMethods;
					}
					else if (line.indexOf(" = function(") >= 0 && line.indexOf("var ") >= 0) {
						var first = 0;
						var last = line.indexOf(".");
						var internal_name = line.substr(first, last - first);
						currentClass = classes[internal_name];

						first = line.indexOf('.') + 1;
						last = line.indexOf(' ');
						var methodname = line.substr(first, last - first);
						if (!currentClass.methods.exists(methodname)) {
							currentFunction = new Func();
							currentFunction.name = methodname;
							first = line.indexOf('(') + 1;
							last = line.lastIndexOf(')');
							var last_param_start = first;
							for (i in first...last + 1) {
								if (line.charAt(i) == ',') {
									currentFunction.parameters.push(line.substr(last_param_start, i - last_param_start));
									last_param_start = i + 1;
								}
								if (line.charAt(i) == ')') {
									currentFunction.parameters.push(line.substr(last_param_start, i - last_param_start));
									break;
								}
							}

							//printf("Found method %s.\n", methodname.c_str());
							currentClass.methods[methodname] = currentFunction;
						}
						else {
							currentFunction = currentClass.methods[methodname];
						}
						mode = ParseFunction;
						currentBody = "";
						brackets = 1;
					}
					// hxClasses["BigBlock"] = BigBlock;
					// var BigBlock = $hxClasses["BigBlock"] = function(xx,yy) {
					else if (line.indexOf("$hxClasses[\"") >= 0) { //(startsWith(line, "$hxClasses[\"")) {
						var first = line.indexOf('\"');
						var last = line.lastIndexOf('\"');
						var name = line.substr(first + 1, last - first - 1);
						first = line.indexOf(' ');
						last = line.indexOf(' ', first + 1);
						var internal_name = line.substr(first + 1, last - first - 1);
						if (!classes.exists(internal_name)) {
							//printf("Found type %s.\n", internal_name.c_str());
							currentClass = new Klass();
							currentClass.name = name;
							currentClass.internal_name = internal_name;
							classes[internal_name] = currentClass;
							++types;
						}
						else {
							currentClass = classes[internal_name];
						}
					}
				}
				case ParseMethods: {
					// ,draw: function(g) {
					if (line.endsWith("{")) {
						var first = 0;
						while (line.charAt(first) == ' ' || line.charAt(first) == '\t' || line.charAt(first) == ',') {
							++first;
						}
						var last = line.indexOf(':');
						var methodname = line.substr(first, last - first);
						if (!currentClass.methods.exists(methodname)) {
							currentFunction = new Func();
							currentFunction.name = methodname;
							first = line.indexOf('(') + 1;
							last = line.lastIndexOf(')');
							var last_param_start = first;
							for (i in first...last + 1) {
								if (line.charAt(i) == ',') {
									currentFunction.parameters.push(line.substr(last_param_start, i - last_param_start));
									last_param_start = i + 1;
								}
								if (line.charAt(i) == ')') {
									currentFunction.parameters.push(line.substr(last_param_start, i - last_param_start));
									break;
								}
							}
						
							//printf("Found method %s.\n", methodname.c_str());
							currentClass.methods[methodname] = currentFunction;
						}
						else {
							currentFunction = currentClass.methods[methodname];
						}
						mode = ParseMethod;
						currentBody = "";
						brackets = 1;
					}
					else if (line.endsWith("};") || line.endsWith("});")) { // Base or extended class
						mode = ParseRegular;
					}
				}
				case ParseMethod: {
					if (line.indexOf('{') >= 0) ++brackets;
					if (line.indexOf('}') >= 0) --brackets;
					if (brackets > 0) {
						currentBody += line + " ";
					}
					else {
						if (currentFunction.body == "") {
							currentFunction.body = currentBody;
						}
						else if (currentFunction.body != currentBody) {
							currentFunction.body = currentBody;
							
							// BlocksFromHeaven.prototype.loadingFinished = new Function([a, b], "lots of text;");
							var script = "";
							script += currentClass.internal_name;
							script += ".prototype.";
							script += currentFunction.name;
							script += " = new Function([";
							for (i in 0...currentFunction.parameters.length) {
								script += "\"" + currentFunction.parameters[i] + "\"";
								if (i < currentFunction.parameters.length - 1) script += ",";
							}
							script += "], \"";
							script += currentFunction.body.replace("\"", "\\\"");
							script += "\");";
							
							// Kore::log(Kore::Info, "Script:\n%s\n", script.c_str());
							//sendLogMessage("Patching method %s in class %s.", currentFunction->name.c_str(), currentClass->name.c_str());
							
							//**
						}
						mode = ParseMethods;
					}
				}
				case ParseFunction: {
					if (line.indexOf('{') >= 0) ++brackets;
					if (line.indexOf('}') >= 0) --brackets;
					if (brackets > 0) {
						currentBody += line + " ";
					}
					else {
						if (currentFunction.body == "") {
							currentFunction.body = currentBody;
						}
						else if (currentFunction.body != currentBody) {
							currentFunction.body = currentBody;

							// BlocksFromHeaven.prototype.loadingFinished = new Function([a, b], "lots of text;");
							var script = "";
							script += currentClass.internal_name;
							script += ".";
							script += currentFunction.name;
							script += " = new Function([";
							for (i in 0...currentFunction.parameters.length) {
								script += "\"" + currentFunction.parameters[i] + "\"";
								if (i < currentFunction.parameters.length - 1) script += ",";
							}
							script += "], \"";
							script += currentFunction.body.replace("\"", "\\\"");
							script += "\");";

							// Kore::log(Kore::Info, "Script:\n%s\n", script.c_str());
							//sendLogMessage("Patching function %s in class %s.", currentFunction->name.c_str(), currentClass->name.c_str());

							//**
						}
						mode = ParseRegular;
					}
				}
			}
		}
		//sendLogMessage("%i new types found.", types);
	}
}
