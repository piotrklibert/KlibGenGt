package pl.klibert.klibgen.core

import kotlinx.collections.immutable.PersistentList
import kotlinx.collections.immutable.toPersistentList
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.serializer

open class PersistentListSerializer<T>(
    elementSerializer: KSerializer<T>,
) : KSerializer<PersistentList<T>> {
    private val delegate = ListSerializer(elementSerializer)

    override val descriptor: SerialDescriptor = delegate.descriptor

    override fun serialize(encoder: Encoder, value: PersistentList<T>) {
        delegate.serialize(encoder, value)
    }

    override fun deserialize(decoder: Decoder): PersistentList<T> =
        delegate.deserialize(decoder).toPersistentList()
}

object StringListSerializer : PersistentListSerializer<String>(serializer())

object HtmlAttributeListSerializer : PersistentListSerializer<HtmlAttribute>(HtmlAttribute.serializer())

object PostNodeListSerializer : PersistentListSerializer<PostNode>(PostNode.serializer())
