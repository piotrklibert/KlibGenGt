package pl.klibert.klibgen.core

import arrow.optics.optics
import kotlinx.collections.immutable.PersistentList
import kotlinx.collections.immutable.persistentListOf
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

@Serializable
@optics
data class BlogPost(
    val schemaVersion: Int = 1,
    val slug: String,
    val metadata: PostMetadata,
    @Serializable(with = PostNodeListSerializer::class)
    val nodes: PersistentList<PostNode> = persistentListOf(),
) {
    companion object
}

@Serializable
@optics
data class PostMetadata(
    val title: String,
    val publication: PublicationState = PublicationState.Draft,
    val author: Author? = null,
    val summary: String? = null,
    val canonicalUrl: String? = null,
    @Serializable(with = StringListSerializer::class)
    val tags: PersistentList<String> = persistentListOf(),
    @Serializable(with = StringListSerializer::class)
    val legacyIds: PersistentList<String> = persistentListOf(),
) {
    companion object
}

@Serializable
@optics
data class Author(
    val name: String,
    val email: String? = null,
    val url: String? = null,
) {
    companion object
}

@Serializable
sealed interface PublicationState {
    @Serializable
    @SerialName("draft")
    data object Draft : PublicationState

    @Serializable
    @SerialName("published")
    data class Published(
        val publishedAt: String,
        val updatedAt: String? = null,
    ) : PublicationState
}

@Serializable
@optics
data class HtmlAttribute(
    val name: String,
    val value: String,
) {
    companion object
}

@Serializable
sealed interface PostNode {
    @Serializable
    @SerialName("raw_source")
    data class RawSource(
        val format: String,
        val source: String,
    ) : PostNode

    @Serializable
    @SerialName("dom_fragment")
    data class DomFragment(
        val tagName: String,
        @Serializable(with = HtmlAttributeListSerializer::class)
        val attributes: PersistentList<HtmlAttribute> = persistentListOf(),
        @Serializable(with = PostNodeListSerializer::class)
        val children: PersistentList<PostNode> = persistentListOf(),
    ) : PostNode

    @Serializable
    @SerialName("my_img")
    data class MyImage(
        val src: String,
        val alt: String,
        val caption: String? = null,
        @Serializable(with = HtmlAttributeListSerializer::class)
        val attributes: PersistentList<HtmlAttribute> = persistentListOf(),
    ) : PostNode

    @Serializable
    @SerialName("footnote_ref")
    data class FootnoteReference(
        val id: String,
    ) : PostNode

    @Serializable
    @SerialName("footnote_def")
    data class FootnoteDefinition(
        val id: String,
        @Serializable(with = PostNodeListSerializer::class)
        val content: PersistentList<PostNode> = persistentListOf(),
    ) : PostNode

    @Serializable
    @SerialName("heading")
    data class Heading(
        val level: Int,
        val id: String? = null,
        @Serializable(with = PostNodeListSerializer::class)
        val content: PersistentList<PostNode> = persistentListOf(),
    ) : PostNode

    @Serializable
    @SerialName("section")
    data class Section(
        val heading: Heading? = null,
        @Serializable(with = PostNodeListSerializer::class)
        val content: PersistentList<PostNode> = persistentListOf(),
    ) : PostNode

    @Serializable
    @SerialName("text")
    data class Text(
        val value: String,
    ) : PostNode

    @Serializable
    @SerialName("unknown_legacy")
    data class UnknownLegacyNode(
        val name: String,
        val payload: JsonElement? = null,
    ) : PostNode
}

object BlogPostJson {
    val format: Json = Json {
        classDiscriminator = "kind"
        encodeDefaults = true
        explicitNulls = false
        ignoreUnknownKeys = true
        prettyPrint = true
    }

    fun encode(post: BlogPost): String =
        format.encodeToString(BlogPost.serializer(), post)

    fun decode(source: String): BlogPost =
        format.decodeFromString(BlogPost.serializer(), source)
}
