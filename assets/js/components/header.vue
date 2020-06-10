<template>
  <section class="content-header">
    <div class="container-fluid">
      <div class="row mb-2">
        <div class="col-sm-6">
          <h1>List of Menu items</h1>
        </div>
      </div>
    </div>
    <!-- tile header end -->
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header">
            <div>
              <button
                class="btn btn-success"
                data-toggle="modal"
                data-target="#additem"
              >Add New Item</button>
            </div>

            <div
              class="modal fade"
              id="additem"
              tabindex="-1"
              role="dialog"
              aria-labelledby="exampleModalLabel"
              aria-hidden="true"
            >
              <div class="modal-dialog" role="document">
                <div class="modal-content">
                  <div class="modal-header">
                    <h5 class="modal-title" id="exampleModalLabel">New Item</h5>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                      <span aria-hidden="true">&times;</span>
                    </button>
                  </div>
                  <div class="modal-body">
                    <div class="form-group">
                      <label for="itemname">Item name</label>
                      <input id="itemname" v-model="itemName" type="text" class="form-control" />
                    </div>
                    <div class="form-group">
                      <label for="itemprice">Item price</label>
                      <input type="number" v-model="itemPrice" class="form-control" />
                    </div>
                    <div class="form-group">
                      <label for="itemdepts">Item Departement</label>
                      <select
                        id="itemdepts"
                        v-model="deptSelected"
                        type="text"
                        class="form-control"
                      >
                        <option>--- Choose Departement ---</option>
                        <option
                          :key="dept.id"
                          :value="dept.id"
                          class="form-control"
                          v-for="dept in depts"
                        >{{dept.name.toUpperCase()}}</option>
                      </select>
                    </div>
                    <div class="form-group">
                      <label for="itemcategory">Item category</label>
                      <select
                        id="itemcategory"
                        type="text"
                        v-model="catSelected"
                        class="form-control"
                      >
                        <option>--- Choose Category ---</option>
                        <option
                          :key="cat.id"
                          :value="cat.id"
                          class="form-control"
                          v-for="cat in cats_$"
                        >{{cat.name.toUpperCase()}}</option>
                      </select>
                    </div>
                  </div>
                  <div class="modal-footer">
                    <button type="button" class="btn btn-primary" @click="saveItem()">Save Item</button>
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                  </div>
                </div>
              </div>
            </div>
            <div style="display:flex;justify-content: flex-end">
              <div class="mr-2">
                <div class="form-group">
                  <input class="form-control" v-model="filtering_$" placeholder="...search" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>

  <!-- other header end -->
</template>

<script>
export default {
  props: ["depts", "cats"],
  data() {
    return {
      query: "",
      deptSelected: undefined,
      catSelected: undefined,
      itemName: "",
      itemPrice: ""
    };
  },
  created() {},
  mounted() {},
  computed: {
    cats_$() {
      if (this.deptSelected != "") {
        return this.cats.filter(cat => cat.departement_id == this.deptSelected);
      }
      return this.cats;
    },
    filtering_$: {
      get: function() {
        return this.query;
      },
      set: function(val) {
        this.query = val;
        console.log("heeeeeeeeeeeee", val);
        this.$emit("filtering", val);
      }
    }
  },
  methods: {
    filtering(e) {
      console.log("filtering google it", e);
    },
    saveItem() {
      this.$emit("newitem", {
        price: this.itemPrice,
        name: this.itemName,
        dpt_id: this.deptSelected,
        category_id: this.catSelected
      });
    }
  }
};
</script>