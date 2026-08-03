package pl.klibert.klibgen.core

fun main() {
    val post = SampleBlogPosts.representative()
    val decoded = BlogPostJson.decode(BlogPostJson.encode(post))
    check(decoded == post) { "BlogPost JSON round trip failed" }

    val pythonResult = GraalPythonSmoke.evaluateIntExpression(
        """__import__("json").loads('{"value": 42}')["value"]""",
    )
    check(pythonResult == 42) { "GraalPy smoke evaluation returned $pythonResult" }

    println("klibgen-core smoke ok")
}
