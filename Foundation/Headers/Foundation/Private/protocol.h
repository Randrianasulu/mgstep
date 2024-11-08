/* These structures used to be public, but are now private to the runtime.  */

#ifndef __objc_private_protocol
#define __objc_private_protocol


/* Note that a 'struct objc_method_description' as embedded inside a
   Protocol uses the same trick as a 'struct objc_method': the
   method_name is a 'char *' according to the compiler, who puts the
   method name as a string in there.  At runtime, the selectors need
   to be registered, and the method_name then becomes a SEL.  */
struct objc_method_description_list {

  int count;
  struct objc_method_description list[1];
};

#ifdef NEW_RUNTIME

struct objc_protocol {

  struct objc_class* class_pointer;
  char *protocol_name;
  struct objc_protocol_list *protocol_list;
  struct objc_method_description_list *instance_methods, *class_methods; 
};


struct objc_protocol_list {

  struct objc_protocol_list *next;
  size_t count;
  struct objc_protocol *list[1];
};

#endif

#endif  /* __objc_private_protocol */
