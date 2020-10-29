template<typename T>
struct Null_Free_Function
{
  static void free(T * obj) { }
};
