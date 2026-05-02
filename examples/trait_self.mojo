from std.reflection import reflect


trait ReflectsSelf:
    @staticmethod
    def describe_self():
        comptime self_info = reflect[Self]()

        print("Self type: " + self_info.name())
        print("field count: " + String(self_info.field_count()))

        comptime for i in range(self_info.field_count()):
            comptime field_name = self_info.field_names()[i]
            comptime field_type = self_info.field_types()[i]
            print(
                "  "
                + field_name
                + ": "
                + reflect[field_type]().name()
            )


@fieldwise_init
struct EmptyModel(ReflectsSelf):
    pass


@fieldwise_init
struct DeviceModel(ReflectsSelf):
    var hostname: String
    var enabled: Bool
    var mtu: Int


def main():
    print("EmptyModel.describe_self()")
    EmptyModel.describe_self()
    print("")

    print("DeviceModel.describe_self()")
    DeviceModel.describe_self()
