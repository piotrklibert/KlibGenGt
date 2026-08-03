package pl.klibert.klibgen.core

import org.graalvm.polyglot.Context

object GraalPythonSmoke {
    fun evaluateIntExpression(source: String): Int =
        Context.newBuilder("python")
            .allowAllAccess(false)
            .option("engine.WarnInterpreterOnly", "false")
            .build()
            .use { context ->
                val value = context.eval("python", source)
                require(value.fitsInInt()) { "Python expression did not produce an Int: $source" }
                value.asInt()
            }
}
