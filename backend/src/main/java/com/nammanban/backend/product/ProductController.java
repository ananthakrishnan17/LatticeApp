package com.nammanban.backend.product;

import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;

import static com.nammanban.backend.product.ProductDtos.ProductResponse;
import static com.nammanban.backend.product.ProductDtos.ProductUpsertRequest;

@RestController
@RequestMapping("/products")
public class ProductController {

    private final ProductService service;

    public ProductController(ProductService service) {
        this.service = service;
    }

    @PostMapping("/upsert")
    public ProductResponse upsert(@Valid @RequestBody ProductUpsertRequest request) {
        return service.upsert(request);
    }

    @GetMapping
    public List<ProductResponse> list() {
        return service.list();
    }
}
