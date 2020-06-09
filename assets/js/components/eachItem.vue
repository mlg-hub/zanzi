<template>
  <tr>
    <td>{{item.name}}</td>
    <td>{{item.departement.name}}</td>
    <td>{{item.price}}</td>
    <td style="display:flex; justify-content: space-around">
      <span style="cursor: pointer" data-toggle="modal" :data-target="'#exampleModal' + item.id">
        <i style="color: orange" class="fas fa-edit"></i>
      </span>
      <span style="cursor: pointer">
        <i style="color: orangered" class="fas fa-trash"></i>
      </span>
    </td>
    <div
      class="modal fade"
      :id="'exampleModal' + item.id"
      tabindex="-1"
      role="dialog"
      aria-labelledby="exampleModalLabel"
      aria-hidden="true"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="exampleModalLabel">Edit Item</h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label class="label" for="name">Item name:</label>
              <input id="name" class="form-control" v-model="itemUpdated.name" />
            </div>
            <div class="form-group">
              <label class="label" for="price">Item Price:</label>
              <input class="form-control" v-model="itemUpdated.price" />
            </div>
            <div class="form-group">
              <label class="label" for="dpt">Item departement:</label>
              <select class="form-control" v-model="selectedDept">
                <option
                  :value="id"
                  v-for="{name, id} in depts"
                  :key="id"
                  :selected="item.departement.name == name"
                >{{name}}</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
            <button type="button" class="btn btn-primary" @click="updateItems()">Save changes</button>
          </div>
        </div>
      </div>
    </div>
  </tr>
</template>
<script>
export default {
  props: ["item", "depts", "itemchanged"],
  created: function() {},
  mounted: function() {},
  data: function() {
    return {
      adminchannel: undefined,
      selectedDept: undefined,
      itemUpdated: {
        id: undefined,
        name: undefined,
        price: undefined
      }
    };
  },
  created: function() {
    if (!!this.item.departement.name) {
      console.log("heellooo!!", this.item.departement);
      this.selectedDept = this.item.departement.id;
      this.itemUpdated.name = this.item.name;
      this.itemUpdated.price = this.item.price;
      this.itemUpdated.id = this.item.id;
    }
  },
  methods: {
    updateItems() {
      console.log("...updating");
      this.$emit("updating", {
        ...this.itemUpdated,
        selectedDept: this.selectedDept
      });
    }
  }
};
</script>